`live:geo:{universityId}` is written on every broadcast point but never read or trimmed (no GEOSEARCH, no ZREM, no TTL), so it accumulates one member per run forever.
