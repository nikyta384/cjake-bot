# CJake - Telegram Crypto News Collector

Hey there! This is CJake, a simple tool I built to keep track of crypto news and alerts from various Telegram channels. It pulls messages from channels like ones about market news, airdrops, and analytics, stores them in a database called ChromaDB, and lets you query recent stuff through a bot. You can use it to stay updated on crypto without checking every channel manually – like getting a summary of hot news from the last few hours. It's deployed on AWS for automatic updates, and it's great for traders or anyone into crypto who wants quick insights.

The app has two main functions for users: first, you can click a button in the Telegram bot to get a summary of all news (that's TG messages and posts) from the last 1 hour. It pulls the recent ones from ChromaDB and gives you a quick overview. Second, you can just write a question to the bot, and it will search the ChromaDB for info related to your question, like finding details on a specific crypto event or alert. To use the bot, you need to create your own Telegram bot first – go to BotFather in Telegram, make a new bot, and get its token. That's what you'll use in the secrets.

You can run it locally if you want, but the real power is in the cloud setup where it fetches messages periodically and you can interact with the bot. Just set up the channels in `src/channels.yaml`.

## How the Bot Works

Here are a couple of screenshots showing the bot in action:

![Screenshot of getting a summary by button](screenshots/bot_summary.png)  
*Example of clicking the button to get a 1-hour news summary.*

![Screenshot of asking a question to the bot](screenshots/bot_query.png)  
*Example of writing a question and getting a response from ChromaDB search.*

(Replace the image paths with your actual screenshot files, e.g., add them to a `screenshots` folder in the repo.)

## How to Set Up the Infrastructure

This project uses AWS for everything – from building and deploying the app to running it on ECS. All the Terraform files are in the `iac` folder, so that's where you'll do the setup. I have it connected to my private GitHub repo using AWS CodeStar Connections, but you can tweak it for yours. Note that there's a missing file `tg_collector.7z` – that's the archived Telegram session, which I'll explain later.

### Prerequisites
- An AWS account with permissions to create resources like ECS, ECR, CodePipeline, etc.
- Terraform installed (version 1.4 or higher).
- A GitHub repo (private or public) with this code. I used `nikyta384/cjake` as private.
- AWS CLI set up and configured.
- Secrets like OpenAI API key, Telegram bot token, API ID, API hash, and archive password – you'll pass them as vars.
- A CodeStar Connection to your GitHub. Create one in AWS console if you don't have (mine is named `nikyta384-github`).

### Steps to Deploy
1. **Clone the repo**: Get the code from your GitHub. If it's private like mine, make sure you're authenticated.

2. **Go to iac folder**: `cd cjake/iac`

3. **Update variables**: Open `variables.tf` and set your own values, like `aws_region`, `project_prefix` (I use "cjake"), `github_owner`, `github_repo`, `github_branch`, and `codestar_connection_name`. Also, prepare your secret values (don't commit them!).

4. **Initialize Terraform**: Run `terraform init` to get the providers.

5. **Plan and Apply**: 
   - `terraform plan -var="openai_api_key=your_key" -var="bot_token=your_token" -var="tg_api_id=your_id" -var="tg_api_hash=your_hash" -var="tg_archive_pass=your_pass"` (replace with your secrets).
   - If it looks good, `terraform apply` with the same vars. This will create:
     - ECR repo for Docker images.
     - ECS cluster, task, and service with ChromaDB and app containers.
     - CodePipeline for CI/CD, connected to GitHub via CodeStar.
     - CodeBuild project to build and push Docker images using `buildspec.yml`.
     - Secrets in Secrets Manager.
     - IAM roles, VPC and security groups, S3 for artifacts.

6. **Build and Deploy**: Once Terraform is done, push code to your GitHub branch. CodePipeline will trigger, build the Docker image from `Dockerfile`, push to ECR, and deploy to ECS. Check AWS console for logs in CloudWatch (`/ecs/cjake` group).

7. **Add the missing archive**: Upload `tg_collector.7z` to the right place – more on that below. The Dockerfile extracts it with the password from secrets.


## How to Create the Telegram Session Archive

The app needs a Telegram session to connect without logging in every time. For this purpose I used another TG account. Please don't use your own TG accoutn. It will be stored in `tg_collector.7z`. Here's how to make it:

1. **Get Telethon**: Use Python with Telethon library (it's in `src/requirements.txt`).

2. **Create a session**: Write a small script like this (not in the repo, run locally):
   ```python
   from telethon.sync import TelegramClient
   from telethon.sessions import StringSession

   api_id = your_tg_api_id  # from https://my.telegram.org
   api_hash = 'your_tg_api_hash'
   phone = '+your_phone_number'

   client = TelegramClient(StringSession(), api_id, api_hash)
   client.start(phone=phone)  # It will ask for code and password if 2FA.
   print(client.session.save())  # This prints the session string, but better save to file.
   client.session.save_to_file('tg_collector.session')  # Or something like that.
   ```

3. **Archive it**: Use 7-Zip to compress `tg_collector.session` into `tg_collector.7z` with a password (that's `tg_archive_pass` in vars). Command: `7z a -pYourPassword tg_collector.7z tg_collector.session`

4. **Place it**: Put `tg_collector.7z` in the `src` folder before building the Docker image. The `Dockerfile` extracts it at runtime using the password from secrets.

In `main.py`, it connects with `client.start()` – make sure the session is valid for your account. If you change channels, update `src/channels.yaml` with priorities and summaries.

That's it! Once running, the ECS service will have the app collecting messages, and you can extend the bot in `src/main.py` for more features. If you need help, check AWS docs or Telethon github. Let me know if I missed something!