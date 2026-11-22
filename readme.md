#### feed utils
	opml reader/writer
	
	buku database reader/writer

#### feed store reader

`feedstore.v` provides a unified reader for reader-local RSS storage formats:

```v
res := feedut.feed_store_load(path)!
for feed in res.feeds {
    println('${feed.group_raw} | ${feed.title} | ${feed.url}')
    for item in feed.items { println('  ${item.title}') }
}
groups := feedut.feed_store_groups(res.feeds)
```

Supported formats (auto-detected from file magic/schema or directory layout):

| kind | reader / format | source |
|------|----------------|--------|
| `.rss` | RSS 2.0 / Atom / RDF single file | `parse_feed` |
| `.opml` | generic OPML (recursive outlines -> group_path) | self-written scanner |
| `.sfeed` | sfeed TSV (physical folders -> group_path) | text |
| `.claws` | Claws Mail RSSyl directory + RFC 822 messages | OPML + message files |
| `.liferea` | Liferea SQLite (folders -> group_path, vfolder ignored) | `db.sqlite` |
| `.newsboat` | newsboat `urls` file (tags -> feed.tags) | text |
| `.rssguard` | RSS Guard `feed`/`entry` SQLite | `db.sqlite` |
| `.quiterss` | QuiteRSS `feeds`/`news` SQLite | `db.sqlite` |
| `.firefox` | Firefox legacy livemarks in `places.sqlite` | `db.sqlite` |
| `.thunderbird` | Thunderbird RSS prefs | `prefs.js` |
| `.netnewswire` | NetNewsWire Core Data (`ZFEED`) | `db.sqlite` |
| `.vienna` | Vienna `feed`/`article` SQLite | `db.sqlite` |
| `.feedme` | FeedMe generic `feed`/`item` SQLite | `db.sqlite` |
| `.elfeed` | elfeed org-mode `:feed-url:` | text |
| `.opera` | Opera Mail account `.ini` files | text |
| `.akregator` | Akregator OPML export | OPML |

Notes:
- `group_path` is always the **physical folder hierarchy**. Tags/labels stay in
  `StoreFeed.tags`; `StoredItem.category` is per-entry. Liferea `vfolder` nodes
  are never included in `group_path`.
- SQLite stores are copied to a private temp file before reading so live reader
  databases are never locked or modified.
- OPML uses a quote-aware scanner rather than `xmlc`, because `xmlc` truncates
  attribute values at the first space and does not decode entity references.
- `feed_store_detect()` returns `StoreKind`; `feed_store_load()` returns a
  `StoreResult` with normalized `[]StoreFeed`. `feed_store_groups()` builds a
  physical folder tree from the normalized feeds.
