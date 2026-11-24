# Deploy and Host Poznote on Railway

Poznote is an open-source (MIT) note-taking web app. It keeps rich-text, Markdown, task-list and Excalidraw notes in workspaces, folders and tags, with full-text search, attachments, revisions, a Kanban view, public sharing links, several user profiles and a REST API. Everything is stored in SQLite and plain files.

## About Hosting Poznote

This template runs Poznote 6.158.2 from the official image as a single service. nginx, PHP-FPM and Poznote's background workers run in that one container, and a Railway volume at `/var/www/html/data` holds the SQLite databases, notes, attachments and backups, so your data survives redeploys and restarts. Upstream ships a default admin (`admin_change_me` / `admin`). On the first boot, this template renames it to `admin` and gives it a generated password before the web server accepts any request, so the public URL is never open. PHP and nginx workers are sized from the service's memory and CPU limits, so it runs on 0.5 GB.

## Common Use Cases

* A private notes and documentation space you reach from any browser or install as a PWA
* A shared team knowledge base with separate user profiles, workspaces and public share links
* Task lists, Kanban boards, diagrams and a daily journal in one place, with backups you control

## Dependencies for Poznote Hosting

* A Railway volume for `/var/www/html/data` (included)
* Nothing else: Poznote uses SQLite inside the volume

### Deployment Dependencies

* Poznote source and docs: https://github.com/timothepoznanski/Poznote
* Template repo: https://github.com/aalfath/poznote-railway-template

### Implementation Details

**Services:** one service, `Poznote`: the public web app (nginx + PHP-FPM + workers), health check `/api/health`, volume `/var/www/html/data`.

**After deploy:**

1. Open the Railway URL and sign in as `admin` with the password in the service's `POZNOTE_ADMIN_PASSWORD` variable (Variables tab).
2. Change the password under Settings > My Account, and add other users under Settings > Admin Tools if you need them.
3. Optional: set the instance URL, SMTP, OIDC sign-in, S3 backups or AI features from Settings > Admin Tools. None is needed to start.

`POZNOTE_ADMIN_USERNAME` and `POZNOTE_ADMIN_PASSWORD` are used only on the first boot. Later changes are made in the app, and the variables are ignored.

**Not included:** upstream's optional MCP server. It reads the web container's token file through a shared Docker volume, which Railway doesn't offer.

**Memory:** about 60-120 MB idle. Large imports, exports and backups need more, so 1 GB is comfortable for several users.

**Updates:** the service builds from the GitHub repo above, which pins the official image by version and digest. When a new Poznote release is tested and merged, Railway shows an "update available" notice on your project, and you choose when to apply it. Read `CHANGELOG.md` in the repo first. Back up from Settings > Backup before a big upgrade.

## Why Deploy Poznote on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Poznote on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->
