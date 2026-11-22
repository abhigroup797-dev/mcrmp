# Moulding Stock & Costing

Stock, material costs and production cost for an injection moulding shop. It runs as a website on GitHub Pages at `mcrmp.arapvtltd.com` and keeps its data in the same Supabase project as Mould CRM, with the same logins.

What it does:

- Stock of resins, masterbatch, inserts, packaging and finished parts, with cost per unit, stock value and a reorder warning
- Purchases, issues, sales, scrap and adjustments as transactions; every transaction moves the stock
- A purchase can move the item's cost to the weighted average, and every cost change is logged
- A costing sheet per part: cost per piece from part weight, runner, cavities, cycle time, machine and labour rates, rejection, mould life, packing and overhead, and a selling price at your margin
- Log a production run from a costing sheet: resin and masterbatch go out, good pieces come in at their cost, in one step
- The same data on every phone and computer; CSV and backup downloads

## Files

| File | What it is |
|---|---|
| `index.html` | The website |
| `config.js` | The Supabase project URL and publishable key (already the same as in `mould-crm`) |
| `supabase-setup.sql` | Creates this site's table, access rules and stock functions |
| `CNAME` | Tells GitHub Pages the site's address, `mcrmp.arapvtltd.com` |
| `manifest.webmanifest`, `icon-*.png` | Name and icon when the site is added to a phone's home screen |

## Setup (one time)

Do the steps in this order.

### 1. Create this site's table in Supabase

1. Open your Supabase project (the one Mould CRM uses).
2. Open **SQL Editor**, click **New query**, paste everything from `supabase-setup.sql` and click **Run**.

It is safe to run again. It does not change anything that belongs to Mould CRM. If it says `public.profiles is missing`, run the Mould CRM `supabase-setup.sql` first.

### 2. Turn on the website

1. In this GitHub repository open **Settings**, then **Pages**.
2. Under **Build and deployment** choose **Deploy from a branch**, branch **main**, folder **/ (root)**, and save.
3. On the same page, **Custom domain** should show `mcrmp.arapvtltd.com` (it comes from the `CNAME` file). If it is empty, type it in and save.

On a free GitHub account the repository must be public for Pages to work.

### 3. Point the domain at the website (GoDaddy)

Do this after step 2, not before.

1. Sign in to GoDaddy, open the domain `arapvtltd.com` and open **DNS**.
2. Add a new record: Type **CNAME**, Name **mcrmp**, Value **abhigroup797-dev.github.io**. Leave TTL as it is and save.
3. Wait until `http://mcrmp.arapvtltd.com` opens the site. This can take from a few minutes to a day.
4. Back in GitHub **Settings**, **Pages**, tick **Enforce HTTPS** when it becomes available.

### 4. Log in

Open `https://mcrmp.arapvtltd.com` and log in with the admin email and password you use for Mould CRM.

## Good to know

- **Who can open it:** the admin always, plus anyone the admin gives access to in the **Users** tab of the site. The admin can also add a new user there. A person with access sees and changes everything, including costs.
- **More than one resin:** on a costing sheet use "Add another resin" and give each resin its share in %. A production run takes each resin out of stock in that share.
- **Passwords:** changed in Mould CRM, or by the admin in Supabase. The "Create admin account" form shows only while no admin exists.
- **Stock changes only through transactions.** To correct a quantity, record an Adjustment. Deleting a transaction takes its stock change back.
- **Sample data:** on an empty database the Stock tab offers "Load sample data to try it". The sample rows are marked `example` and one button removes them all.
- **Phone shortcut:** open the site in Chrome, tap the three dots and choose **Add to Home screen**.
- **Backups:** "Download backup" at the bottom of the page saves everything as one file. "Download CSV" on the Transactions tab opens in Excel.
- **Data is separate:** this site starts empty. Nothing is copied from the earlier version inside Claude.
- **Supabase limits:** this site shares the Supabase project with Mould CRM, so the same plan limits apply to both together.
