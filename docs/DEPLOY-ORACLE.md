# Free test server on Oracle Cloud

Runs the whole system — office dashboard, student and driver apps, API, database, routing — on
Oracle Cloud's **Always Free** ARM server (4 CPUs, 24 GB RAM), with HTTPS and nightly backups.
Cost: nothing, as long as you stay within the Always Free limits. Time: about an hour, most of it
waiting for the first build.

What you get at the end:

| Who | Address |
|-----|---------|
| Transport office | `https://naql-office.duckdns.org` |
| Students | `https://naql-app.duckdns.org` (web app, or the demo APK pointed at this address) |
| Drivers | `https://naql-driver.duckdns.org` |

(The names are examples; you pick your own in step 4.)

---

## 1. Create the Oracle Cloud account

1. Sign up at <https://signup.cloud.oracle.com>. A card is needed to verify identity; Always
   Free resources are not charged.
2. Pick a **home region** close to Iraq, e.g. *UAE East (Dubai)*, *Saudi Arabia West (Jeddah)* or
   *Germany Central (Frankfurt)*. It cannot be changed later, and Always Free servers are only
   created in the home region.

## 2. Create the server

Console → **Compute → Instances → Create instance**:

| Setting | Value |
|---------|-------|
| Name | `naql` |
| Image | **Canonical Ubuntu 24.04** (not "Minimal") |
| Shape | *Change shape* → **Ampere** → `VM.Standard.A1.Flex`, **4 OCPUs, 24 GB memory** |
| Networking | Create new virtual cloud network, **public subnet**, *Assign a public IPv4 address* |
| SSH keys | *Generate a key pair for me* → **download the private key** (you need it to log in) |
| Boot volume | *Specify a custom size* → **100 GB** (free up to 200 GB in total) |

Press **Create**. After a minute the instance page shows the **Public IP address** — note it.

> **"Out of capacity"?** Free ARM servers are popular. Try another *availability domain* in the same
> form, try again later, or upgrade the account to *Pay As You Go* (Always Free resources stay
> free; only resources beyond the free limits would be billed).

## 3. Open ports 80 and 443

Instance page → *Primary VNIC* → the **subnet** → its **Default Security List** → **Add Ingress
Rules**, twice:

| Source CIDR | IP protocol | Destination port |
|-------------|-------------|------------------|
| `0.0.0.0/0` | TCP | `80` |
| `0.0.0.0/0` | TCP | `443` |

Nothing else needs to be open: the database, Redis and the API stay inside the server.

## 4. Get three free domain names (DuckDNS)

HTTPS certificates need domain names. [DuckDNS](https://www.duckdns.org) gives free ones:

1. Sign in (GitHub or Google account).
2. Add three subdomains, e.g. `naql-office`, `naql-app`, `naql-driver`.
3. Set the **current ip** of each to the server's public IP and press *update ip*.

Check from your computer: `ping naql-office.duckdns.org` should show the server's IP.

## 5. Log in and install Docker

From your computer (use the key you downloaded in step 2):

```bash
chmod 600 ~/Downloads/ssh-key-*.key
ssh -i ~/Downloads/ssh-key-*.key ubuntu@YOUR_SERVER_IP
```

On the server:

```bash
# Docker + Compose
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu

# Oracle's Ubuntu image blocks incoming traffic with iptables except SSH: allow web traffic.
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save

exit   # log out and back in so the docker group applies
```

## 6. Configure and start

```bash
ssh -i ~/Downloads/ssh-key-*.key ubuntu@YOUR_SERVER_IP
git clone https://github.com/coderjoher/Naqal-UOWA.git
cd Naqal-UOWA
cp deploy/oracle/env.example .env
nano .env
```

In `.env`:

- the three `*_DOMAIN` lines: your DuckDNS names;
- `ACME_EMAIL`: your email (Let's Encrypt writes there if a certificate is about to expire);
- `JWT_SECRET` and `DB_PASSWORD`: paste the output of `openssl rand -hex 32` (a different one each);
- `DEMO=true` loads the demo university, students and drivers and shows driver sign-in codes on
  screen instead of sending SMS — right for testing.

Save (`Ctrl+O`, `Enter`, `Ctrl+X`) and start:

```bash
./deploy/oracle/up.sh
```

The **first start takes 30–60 minutes**: it downloads the Iraq map and prepares road routing, and
builds the dashboard and both web apps. Later starts take seconds. When the command returns, open
`https://YOUR-OFFICE-NAME.duckdns.org`.

> If the private repository asks for a password at `git clone`, use a GitHub *personal access token*
> (GitHub → Settings → Developer settings → Fine-grained tokens, read access to this repository).

## 7. Sign in and test

| Who | Where | Sign-in |
|-----|-------|---------|
| Office | office address | `office@uowa.edu.iq` / `password123` |
| Super admin | office address | `admin@naql.app` / `password123` |
| Students | student address | `W-1001` … `W-1030` / `student123` |
| Drivers | driver address | `07800000001` … `07800000006`, then the code shown on screen |

**Phones:** the web addresses work in any phone browser (and can be added to the home screen). For
the Android apps, open GitHub → *Releases* → **Demo APKs** on the phone and download
`naql-student.apk` / `naql-driver.apk` (allow installing from this source). On first start tap the
server icon and enter `https://YOUR-STUDENT-NAME.duckdns.org/api` (the same address works for both apps).

Change the demo passwords before giving access to real people.

## Day-to-day

| Task | Command (in `~/Naqal-UOWA`) |
|------|------------------------------|
| Update to the latest version | `git pull && ./deploy/oracle/up.sh` |
| Status | `docker compose ps` |
| API logs | `docker compose logs -f api` |
| Stop everything | `docker compose --profile https --profile backup down` (data is kept) |
| Backups | nightly at 03:00 into `~/Naqal-UOWA/backups`, 14 days kept |
| Restore drill | `docker compose --profile backup run --rm backup restore-drill` |

Everything restarts by itself after a server reboot.

## Moving to real use

Before real students and drivers: set `DEMO=false` (real SMS codes — needs an SMS provider), change
every demo password, set a map provider with a key (`docs/OPERATIONS.md` §8), copy backups off the
server (`BACKUP_REMOTE`), and use the university's own domain names instead of DuckDNS.
`docs/OPERATIONS.md` covers each of these.
