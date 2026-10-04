# Wiki sources

These files are the project's wiki, kept in the repo so changes are reviewed and versioned like the code. Start at [Home.md](Home.md). GitHub's own wiki is a separate git repo, so to publish these there:

1. In the repo's **Settings > Features**, turn on **Wikis**, then create a first page in the **Wiki** tab. GitHub makes the wiki repo (`RSDash_Reloaded.wiki.git`) only once a page exists.
2. Clone it, and copy every `.md` here **except this README** into it.
3. The pages link to each other as `Page-Name.md` so the links work when browsing this folder. Whether the wiki follows `.md` links isn't something I could check, so if links break there, strip the extension from the copies in the wiki clone:

   ```bash
   sed -i -E 's/\]\(([A-Za-z0-9_-]+)\.md(#[^)]*)?\)/](\1\2)/g' *.md
   ```

4. Commit and push the wiki repo. `Home.md` becomes the front page and `_Sidebar.md` the sidebar.

Four of the pages (`FORScan-*.md`) are generated from openRS_'s FORScan catalogue by [`dev/make_wiki_forscan.py`](../../dev/make_wiki_forscan.py). Don't edit them by hand; re-run the script, which also fetches the latest catalogue.
