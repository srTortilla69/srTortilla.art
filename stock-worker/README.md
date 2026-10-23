# Live stock counter

Shows how many copies of each Live painting are left, and marks sold-out pieces on the site.
Snipcart does the actual counting and blocks sales at 0; this small Cloudflare Worker just
reads those numbers so the page can display them (the Snipcart secret key can't go in the page).

Cost: free (Cloudflare Workers free plan, 100,000 requests/day).

## 1. Turn on inventory in Snipcart

1. Snipcart dashboard -> **Store configuration** -> turn **Inventory management** ON.
2. Go to **Products**. Each Live painting (ids 18-24) appears there once Snipcart has crawled it
   (after it's added to a cart, or fetched from `https://srtortilla.art/products.json`).
3. Open each Live painting and set **Stock on hand** to the number of copies you have.
   Use the same number as `stock:` in `index.html`.

   Or do steps 2-3 from code: run `set-stock.ps1` (see "Setting stock from code" below).

## 2. Create the Worker

1. Sign up at https://dash.cloudflare.com (free).
2. **Workers & Pages** -> **Create** -> **Create Worker** -> name it e.g. `srtortilla-stock` -> **Deploy**.
3. **Edit code**, replace everything with the contents of `worker.js`, then **Deploy**.
4. Worker -> **Settings** -> **Variables and Secrets**, add:
   - `SNIPCART_SECRET` - type **Secret** - your Snipcart **secret** API key
     (Snipcart dashboard -> Account -> API keys). Never paste it into `index.html`.
   - `ALLOWED_ORIGIN` - type **Text** - `https://srtortilla.art`
5. Copy the Worker's address, e.g. `https://srtortilla-stock.yourname.workers.dev`.

## 3. Connect the site

In `index.html`, set:

```js
const STOCK_API_URL = 'https://srtortilla-stock.yourname.workers.dev';
```

Commit and push. Check it by opening
`https://srtortilla-stock.yourname.workers.dev/?ids=18,19` - you should see something like
`{"18":1,"19":1}`. `null` means Snipcart isn't tracking stock for that product yet (step 1).

## Setting stock from code

`set-stock.ps1` reads the `stock:` numbers from `index.html` and sends them to Snipcart.
It imports the products first, shows `current -> new` for each one, and only changes anything after you type `y`.
It asks for your Snipcart secret key each time and never saves it.

```
powershell -ExecutionPolicy Bypass -File stock-worker\set-stock.ps1 -DryRun     # preview only
powershell -ExecutionPolicy Bypass -File stock-worker\set-stock.ps1             # all Live paintings
powershell -ExecutionPolicy Bypass -File stock-worker\set-stock.ps1 -Ids 18,21  # just these
```

It **replaces** the count in Snipcart. Run it when you add paintings or restock, not after every
site change - otherwise copies Snipcart already counted as sold come back. Use `-Ids` to touch
only the paintings you're restocking.

## Adding a new Live painting

1. Add it to `index.html` with `category: 'Live'` and a `stock:` number, using the next free id.
2. Add the same id and price to `products.json`.
3. Push, then run `set-stock.ps1 -Ids <new id>` (or set **Stock on hand** in the dashboard).

## Restocking

Change `stock:` in `index.html`, push, then run `set-stock.ps1 -Ids <id>`
(or change **Stock on hand** in the dashboard). The site picks up the new number within about 30 seconds.
