# UK Reddit vs the economy

Tests whether activity on UK money subreddits tracks official UK economic data, Jan 2016 – Aug 2026.

**[View the interactive report](https://anjumahmed99.github.io/uk-reddit-economy/)**

Two models:

- **Poverty model**: hardship-keyword posts in r/UKPersonalFinance (debt, arrears, overdraft, bailiffs, CCJ, IVA, skint, foodbank, payday), with r/DWPhelp as a second check.
- **Road to 100k model**: posts in r/UKPersonalFinance mentioning 100k, promotion, pay rise, bonus, RSUs or equity, with r/FIREUK as a second check.

r/PovertyUK and r/Roadto100kUK don't exist, so these UK communities stand in for them. Every Reddit measure is expressed as posts per 1,000 r/UKPersonalFinance posts, to remove Reddit's own user growth.

Each measure is regressed on CPI inflation, Bank Rate, unemployment, GDP growth (YoY) and wage growth. The models use OLS with Newey–West standard errors (12-month lag), and COVID months (Mar 2020 – Jun 2021) are excluded from fitting. The analysis also checks correlations of year-on-year changes and lead/lag timing.

## Headline results

| | Poverty (hardship posts) | Road to 100k (six-figure posts) |
|---|---|---|
| R² (excl. COVID) | 0.75 | 0.53 |
| Significant drivers (\|t\| ≥ 2) | Unemployment (+), Bank Rate (+), GDP growth (−), wage growth (−), CPI (−) | Bank Rate (+), wage growth (−) |
| Survives year-on-year change test | Bank Rate (r = +0.55) | Bank Rate (r = +0.39) |

Reddit hardship talk mirrors household financial stress (unemployment, interest rates). It does not track GDP growth, and it does not move before the official figures. See the [interactive report](https://anjumahmed99.github.io/uk-reddit-economy/) for charts and caveats.

## Files

| File | What it is |
|---|---|
| `index.html` | Interactive report, served by GitHub Pages |
| `fetch_reddit.sh` | Downloads monthly Reddit post counts from the Arctic Shift archive (resumable, rate-limited) |
| `build_econ.rb` | Merges ONS and Bank of England series into `data/uk_econ_monthly.csv` |
| `analyse.rb` | Builds the Reddit indices, runs the models and writes `data/results.json` |
| `report_template.html`, `report_text.html`, `build_report.rb` | Assemble `index.html` from the results |
| `data/reddit_*.csv` | Monthly post counts per series |
| `data/raw_*` | Raw ONS (ECY2, IHYQ, D7G7, MGSX, KAC3) and Bank of England (IUMABEDR) downloads |

## Rerun

Needs `bash`, `curl`, `jq` and `ruby`.

```bash
./fetch_reddit.sh
ruby build_econ.rb
ruby analyse.rb
LANG=en_US.UTF-8 ruby -E UTF-8 build_report.rb
```

The Reddit fetch takes 30–60 minutes because the archive throttles keyword searches to one month per request.

## Caveats

- Keyword counts are noisy ("equity" also catches home equity) and measure post volume, not sentiment.
- r/UKPersonalFinance posting fell about 40% from early 2024 to early 2026, which inflates all indices in 2025–26.
- Ten years contains roughly one rate cycle, so the Bank Rate result rests heavily on 2022–26.
- Correlation is not causation.
