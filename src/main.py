import os
import time
import yaml
import datetime
import html
import asyncio
from datetime import datetime as dt, timedelta, timezone
from collections import defaultdict
from typing import List, Dict, Any
from telethon import TelegramClient
from openai import OpenAI
import chromadb
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application,
    CommandHandler,
    MessageHandler,
    CallbackQueryHandler,
    ContextTypes,
    filters
)
from telegram.constants import ParseMode
from telegram.error import BadRequest


from dotenv import load_dotenv
load_dotenv()
# === Load environment variables ===
api_id = int(os.getenv("API_ID"))
api_hash = os.getenv("API_HASH")
BOT_TOKEN = os.getenv("BOT_TOKEN")
openai_api_key = os.getenv("OPENAI_API_KEY")
CHROMA_DB_HOST = os.getenv("CHROMA_DB_HOST", 'localhost')
CHROMA_DB_PORT = os.getenv("CHROMA_DB_PORT", 8000)
FETCH_LIMIT = int(os.getenv("FETCH_LIMIT", "500"))
CHANNELS_FILE = os.getenv("CHANNELS_FILE", "channels.yaml")
TIME_TO_FETCH = 3600

# === Load channels from YAML ===
def load_channels(file_path: str) -> Dict[str, Any]:
    """Load channels from a YAML file."""
    with open(file_path, "r") as f:
        return yaml.safe_load(f)

CHANNELS = load_channels(CHANNELS_FILE)

# === Clients setup ===
client = TelegramClient("tg_collector", api_id, api_hash)
openai_client = OpenAI(api_key=openai_api_key)
chroma_client = chromadb.HttpClient(host=CHROMA_DB_HOST, port=CHROMA_DB_PORT)
collection = chroma_client.get_or_create_collection("telegram_messages")

# ===============================================================
# 1️⃣ FETCH TELEGRAM MESSAGES
# ===============================================================
async def fetch_recent_messages(cutoff_time: dt) -> List[Dict[str, Any]]:
    """Fetch recent messages (within the last day) from all channels."""
    await client.start()
    print("✅ Connected to Telegram")

    all_messages = []

    for channel, meta in CHANNELS.items():
        print(f"\n📥 Fetching {channel} (priority={meta['priority']})")

        try:
            entity = await client.get_entity(channel)
        except Exception as e:
            print(f"⚠️ Error getting {channel}: {e}")
            continue

        async for msg in client.iter_messages(entity, limit=FETCH_LIMIT):
            if not msg.text:
                continue
            if msg.date.replace(tzinfo=timezone.utc) < cutoff_time:
                break

            all_messages.append({
                "id": str(msg.id),
                "text": msg.text,
                "date": msg.date,
                "channel": channel,
                "priority": meta["priority"],
                "summary": meta.get("summary", ""),
            })

    return all_messages

# ===============================================================
# 2️⃣ CREATE EMBEDDINGS
# ===============================================================
def embed_messages(messages: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Generate embeddings for messages using OpenAI embeddings API."""
    grouped = defaultdict(list)
    for m in messages:
        grouped[m["date"].strftime("%Y-%m-%d")].append(m)

    embedded_batches = []
    for date_str, group_msgs in grouped.items():
        texts = [m["text"] for m in group_msgs]
        print(f"🧠 Embedding {len(texts)} messages for {date_str}...")

        embeddings = openai_client.embeddings.create(
            model="text-embedding-3-small",
            input=texts
        ).data

        for m, e in zip(group_msgs, embeddings):
            embedded_batches.append({
                "id": f"{m['channel']}_{m['id']}",
                "embedding": e.embedding,
                "text": m["text"],
                "metadata": {
                    "channel": m["channel"],
                    "date": m["date"].isoformat(),
                    "priority": m["priority"],
                    "summary": m["summary"],
                    "date_group": date_str,
                },
            })

    return embedded_batches

# ===============================================================
# 3️⃣ STORE TO CHROMA
# ===============================================================
def store_embeddings(embedded_batches: List[Dict[str, Any]]):
    """Store embeddings into ChromaDB."""
    if not embedded_batches:
        print("ℹ️ No embeddings to store.")
        return

    collection.add(
        ids=[b["id"] for b in embedded_batches],
        embeddings=[b["embedding"] for b in embedded_batches],
        documents=[b["text"] for b in embedded_batches],
        metadatas=[b["metadata"] for b in embedded_batches],
    )

    print(f"✅ Stored {len(embedded_batches)} messages in ChromaDB.")

# ===============================================================
# MAIN WORKFLOW FOR COLLECTOR
# ===============================================================
async def process_cycle():
    now_utc = dt.now(timezone.utc)
    cutoff_time = now_utc - timedelta(seconds=TIME_TO_FETCH)
    print(f"\n📅 Fetching messages newer than: {cutoff_time.isoformat()}")

    messages = await fetch_recent_messages(cutoff_time)
    if not messages:
        print("ℹ️ No new messages found in any channel.")
        return

    embedded_batches = embed_messages(messages)
    store_embeddings(embedded_batches)

    print("💾 Vector DB updated successfully.")

# === HELPER: safe send/edit ===
async def safe_send_or_edit(update_or_query, text):
    """Safely send or edit a message, handling length and parsing issues."""
    MAX_LEN = 3500
    if len(text) > MAX_LEN:
        text = text[:MAX_LEN] + "\n\n...[truncated]..."

    escaped = html.escape(text)
    try:
        if isinstance(update_or_query, Update) and update_or_query.message:
            await update_or_query.message.reply_text(escaped, parse_mode=ParseMode.HTML)
        else:
            await update_or_query.edit_message_text(escaped, parse_mode=ParseMode.HTML)
    except BadRequest:
        try:
            if isinstance(update_or_query, Update) and update_or_query.message:
                await update_or_query.message.reply_text(text)
            else:
                await update_or_query.edit_message_text(text)
        except BadRequest:
            if isinstance(update_or_query, Update) and update_or_query.message:
                await update_or_query.message.reply_text(text)

# === 1️⃣ FEATURE: Question → Find related info from vector DB ===
async def handle_user_query(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle user queries by searching the vector DB and generating a response."""
    query_text = update.message.text.strip()
    await update.message.reply_text(f"🔍 Аналізую запит: “{query_text}”...")

    # --- Create embedding for query ---
    query_embedding = openai_client.embeddings.create(
        model="text-embedding-3-small",
        input=query_text
    ).data[0].embedding

    # --- Search in vector DB ---
    results = collection.query(
        query_embeddings=[query_embedding],
        n_results=10,
        include=["documents", "metadatas", "distances"]
    )

    docs = results.get("documents", [[]])[0]
    metas = results.get("metadatas", [[]])[0]

    if not docs:
        await update.message.reply_text("⚠️ Не знайдено пов’язаних повідомлень.")
        return

    context_text = ""
    for i, doc in enumerate(docs):
        meta = metas[i]
        date = meta.get("date", "unknown")
        channel = meta.get("channel", "unknown")
        context_text += f"- ({date}, {channel}): {doc}\n"

    prompt = f"""
Ти — аналітик криптоканалів у Telegram. 
На основі нижчих повідомлень відповідай на запит користувача коротко та українською мовою. 
Якщо в повідомленнях немає чіткої відповіді — скажи, що даних немає.
На кінці відповіді вкажи канали та час у дужках.

Питання: "{query_text}"

Контекст:
{context_text}
"""

    response = openai_client.chat.completions.create(
        model="gpt-4.1-mini",
        messages=[
            {"role": "system", "content": "Відповідай лише на основі контексту Telegram-повідомлень."},
            {"role": "user", "content": prompt}
        ],
        temperature=0.3,
        max_tokens=600
    )

    answer = response.choices[0].message.content.strip()
    await update.message.reply_text(f"🤖 Відповідь:\n\n{answer}")

# === 2️⃣ FEATURE: Summarize last hour ===
def get_recent_messages(hours: int):
    """Retrieve recent messages from the vector DB based on time cutoff."""
    now = dt.now(timezone.utc)
    cutoff = now - timedelta(hours=hours)

    results = collection.get(include=["documents", "metadatas"])
    messages = []

    for i, meta in enumerate(results["metadatas"]):
        msg_time = dt.fromisoformat(meta["date"])
        if msg_time >= cutoff:
            messages.append({
                "text": results["documents"][i],
                "channel": meta.get("channel", "unknown"),
                "date": meta["date"],
                "priority": meta.get("priority", 3)
            })
    return messages

async def summarize_recent(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Summarize recent messages from the last hour."""
    query = update.callback_query
    await query.answer()
    await query.edit_message_text("🕐 Готую зведення за останню годину...")

    messages = get_recent_messages(1)
    if not messages:
        await safe_send_or_edit(query, "⚠️ Повідомлень за останню годину не знайдено.")
        return

    text_block = ""
    for msg in messages[:30]:
        text_block += f"- ({msg['date']}, {msg['channel']}): {msg['text']}\n"

    prompt = f"""
Підсумуй ключову інформацію з цих Telegram-повідомлень за останню годину.
Виклади коротко українською мовою, групуй за темами.
На кінці кожної теми вкажи канали та час у дужках.

{text_block}
"""

    response = openai_client.chat.completions.create(
        model="gpt-4.1-mini",
        messages=[
            {"role": "system", "content": "Ти — асистент, який підсумовує оновлення з Telegram-каналів."},
            {"role": "user", "content": prompt}
        ],
        temperature=0.5,
        max_tokens=1500
    )

    summary = response.choices[0].message.content.strip()
    await safe_send_or_edit(query, f"🧠 Підсумок за останню годину:\n\n{summary}")

# === /start command ===
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle the /start command and show the menu."""
    keyboard = [
        [InlineKeyboardButton("🕐 SumUp (1h)", callback_data="sumup")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    await update.message.reply_text(
        "👋 Надішли мені будь-яке питання про криптопроєкти (бот знайде відповідь у базі).\n\n"
        "Або натисни кнопку, щоб підсумувати повідомлення за останню годину:",
        reply_markup=reply_markup
    )

# === Callback handler ===
async def handle_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle callback queries from inline buttons."""
    query = update.callback_query
    if query.data == "sumup":
        await summarize_recent(update, context)

# === Collector loop ===
async def collector_loop():
    """Asynchronous loop to periodically run the message collection process."""
    while True:
        await process_cycle()
        await asyncio.sleep(TIME_TO_FETCH)

# === Async main function ===
async def async_main():
    application = Application.builder().token(BOT_TOKEN).build()

    application.add_handler(CommandHandler("start", start))
    application.add_handler(CallbackQueryHandler(handle_callback))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_user_query))

    async with application:
        await application.initialize()
        await application.start()
        await application.updater.start_polling()

        # Start the collector loop as a background task
        asyncio.create_task(collector_loop())

        # Run forever until interrupted (e.g., Ctrl+C)
        stop_event = asyncio.Event()
        try:
            await stop_event.wait()
        except asyncio.CancelledError:
            pass

        await application.updater.stop()
        await application.stop()
        await application.shutdown()

# === MAIN ===
if __name__ == "__main__":
    print("🤖 Bot is running...")
    print("🕒 Collector started, will run every hour...")
    asyncio.run(async_main())