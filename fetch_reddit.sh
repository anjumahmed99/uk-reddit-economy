#!/bin/bash
# Monthly post counts 2016-01..2026-08 from the Arctic Shift Reddit archive.
# Resumable: skips months already saved. Keyword searches use 1-month windows (bigger ones time out on the archive).
B="https://arctic-shift.photon-reddit.com/api/posts/search/aggregate?aggregate=created_utc&frequency=month"
HARD="debt%20OR%20arrears%20OR%20overdraft%20OR%20bailiffs%20OR%20bailiff%20OR%20ccj%20OR%20iva%20OR%20skint%20OR%20foodbank%20OR%20payday"
ASP="100k%20OR%20promotion%20OR%20payrise%20OR%20bonus%20OR%20rsu%20OR%20rsus%20OR%20equity"
fetch() { # name subreddit query
  out="data/reddit_$1.csv"; [ -f "$out" ] || echo "month,count" > "$out"
  step=$([ -n "$3" ] && echo 1 || echo 3)
  for y in $(seq 2016 2026); do for mo in $(seq 1 $step 12); do
    s=$(printf "%d-%02d" $y $mo); [ "$s" \> "2026-08" ] && continue
    grep -q "^$s," "$out" && continue
    em=$((mo+step)); e=$([ $em -gt 12 ] && echo "$((y+1))-01-01" || printf "%d-%02d-01" $y $em)
    r=""
    for try in 1 2 3 4 5 6; do
      r=$(curl -s -m 120 "$B&subreddit=$2&after=$s-01&before=$e${3:+&query=$3}")
      echo "$r" | jq -e '.data|type=="array"' >/dev/null 2>&1 && break; r=""; sleep $((try*8))
    done
    [ -z "$r" ] && { echo "FAILED $1 $s"; continue; }
    # buckets are labelled in CET (e.g. 2015-12-31T23:00 = Jan 2016); shift +12h before taking YYYY-MM
    echo "$r" | jq -r '.data[] | "\(((.created_utc|sub("\\.000Z";"Z")|fromdate)+43200)|strftime("%Y-%m")),\(.count)"' >> "$out"
    sleep 4
  done; done
  { head -1 "$out"; tail -n +2 "$out" | sort -u -t, -k1,1; } > "$out.tmp" && mv "$out.tmp" "$out"
  echo "$1: $(($(wc -l < "$out")-1)) months"
}
fetch dwphelp DWPhelp ""
fetch fireuk FIREUK ""
fetch ukpf_hardship UKPersonalFinance "$HARD"
fetch ukpf_aspiration UKPersonalFinance "$ASP"
