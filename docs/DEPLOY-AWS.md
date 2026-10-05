# Test server on AWS (free plan)

Runs the whole system on one AWS EC2 server with HTTPS and nightly backups, paid from the free
plan's credits. Uses the same scripts as the Oracle guide (`deploy/oracle/`, which work on any
Ubuntu server). Time: about an hour, most of it waiting for the first build.

## What the free plan covers

AWS accounts created on or after 15 July 2025 get a **free plan**: $100 of credits at sign-up and up
to $100 more for completing activities in the console, valid for **6 months** (or until the credits
run out). Instances on the free plan include **`m7i-flex.large` — 2 vCPUs, 8 GB memory**, which is
enough for this system.

Rough monthly use of the credits (check the console for your region's prices):

| Item | Approx. per month |
|------|-------------------|
| `m7i-flex.large`, running all the time | $70 |
| 40 GB disk (gp3) | $3 |
| Public IPv4 / Elastic IP | $4 |

So $100 lasts about 1½ months of continuous running, $200 about 2½–3. **Stop the instance when you
are not testing** (EC2 → Instances → *Stop*): a stopped server only uses the disk and IP. On the free
plan you are never charged money: when the credits or the 6 months run out, AWS asks you to upgrade
to a paid plan, and resources stop if you do not.

## 1. Pick a region

Top right of the console. Closest to Iraq: **Middle East (UAE) `me-central-1`** or **Middle East
(Bahrain) `me-south-1`**. If `m7i-flex.large` is not offered there (step 2), use
**Europe (Frankfurt) `eu-central-1`**, which is still fast from Iraq.

## 2. Launch the server

EC2 → **Launch instance**:

| Setting | Value |
|---------|-------|
| Name | `naql` |
| Image (AMI) | **Ubuntu Server 24.04 LTS**, architecture **64-bit (x86)** |
| Instance type | **`m7i-flex.large`** (marked *Free tier eligible*) |
| Key pair | *Create new key pair* → name `naql`, type RSA, format `.pem` → it downloads; keep it safe |
| Network settings → *Edit* | Auto-assign public IP: **Enable** |
| Security group | *Create security group* with three rules: **SSH** (22) from **My IP**; **HTTP** (80) from **Anywhere**; **HTTPS** (443) from **Anywhere** |
| Storage | **40 GiB**, gp3 |

Press **Launch instance**.

## 3. Give it a fixed address (Elastic IP)

Without this the public IP changes every time the server is stopped and started.

EC2 → **Elastic IPs** → *Allocate Elastic IP address* → *Allocate*. Then select it → *Actions* →
*Associate Elastic IP address* → choose the `naql` instance → *Associate*. Note the address.

## 4. Three free domain names (DuckDNS)

At <https://www.duckdns.org> (sign in with GitHub or Google) add three subdomains, e.g.
`naql-office`, `naql-app`, `naql-driver`, and set each one's IP to the Elastic IP.

## 5. Log in, install Docker, add swap

From your computer, in the folder where `naql.pem` was downloaded:

```bash
chmod 400 naql.pem
ssh -i naql.pem ubuntu@YOUR_ELASTIC_IP
```

(On Windows use PowerShell, the same `ssh` command works; if it complains about the key's
permissions, right-click `naql.pem` → Properties → Security and leave only your own user.)

On the server:

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu

# 4 GB of swap as a safety margin for the first build (road map preparation and app builds run at once).
sudo fallocate -l 4G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

exit   # log out and back in so the docker group applies
```

No firewall changes are needed on AWS: the security group from step 2 already allows 80 and 443.

## 6. Configure and start

```bash
ssh -i naql.pem ubuntu@YOUR_ELASTIC_IP
git clone https://github.com/coderjoher/Naqal-UOWA.git
cd Naqal-UOWA
cp deploy/oracle/env.example .env
nano .env
```

In `.env`: your three DuckDNS names, your email in `ACME_EMAIL`, and for `JWT_SECRET` and
`DB_PASSWORD` the output of `openssl rand -hex 32` (a different one each). Set **`API_WORKERS=2`**
(this server has 2 vCPUs). Keep `DEMO=true` for testing. Save with `Ctrl+O`, `Enter`, `Ctrl+X`, then:

```bash
./deploy/oracle/up.sh
```

The first start takes **30–60 minutes** (Iraq road map, routing preparation, building the three web
apps). When it returns, open `https://YOUR-OFFICE-NAME.duckdns.org`.

> If `git clone` asks for a password (private repository), use a GitHub personal access token
> (GitHub → Settings → Developer settings → Fine-grained tokens, read access to this repository).

## 7. Sign in and test

Same accounts as [DEPLOY-ORACLE.md §7](DEPLOY-ORACLE.md#7-sign-in-and-test): office
`office@uowa.edu.iq` / `password123`, students `W-1001`… / `student123`, drivers
`07800000001`… with the code shown on screen. Android: demo APKs from GitHub → *Actions* → *Apps*,
then enter the student or driver address as the server.

## Day-to-day

| Task | How |
|------|-----|
| Pause to save credits | EC2 → Instances → `naql` → *Instance state* → **Stop** (data is kept) |
| Resume | *Instance state* → **Start**; everything restarts by itself in a minute or two |
| Check remaining credits | Console → **Billing and Cost Management** → *Credits* |
| Update to the latest version | `cd ~/Naqal-UOWA && git pull && ./deploy/oracle/up.sh` |
| Logs | `docker compose logs -f api` |

Backups, restore drill and the move to real use are the same as on Oracle — see
[DEPLOY-ORACLE.md](DEPLOY-ORACLE.md#day-to-day).
