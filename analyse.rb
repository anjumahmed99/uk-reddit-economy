# Builds Reddit indices, runs the two models, writes results JSON for the report page.
require 'json'; require 'csv'
def load(f) return {} unless File.exist?(f); CSV.read(f, headers: true).each_with_object({}) { |r, h| h[r[0]] = r[1].to_f } end
R = %w[ukpf_all ukpf_hardship ukpf_aspiration dwphelp fireuk].to_h { |n| [n, load("data/reddit_#{n}.csv")] }
E = CSV.read('data/uk_econ_monthly.csv', headers: true).each_with_object({}) { |r, h| h[r['month']] = r.to_h.reject { |k, _| k == 'month' }.transform_values { |v| v && !v.empty? ? v.to_f : nil } }
MONTHS = E.keys.select { |m| m <= '2026-08' }.sort

# Indices: posts per 1,000 r/UKPersonalFinance posts, removing Reddit's own user growth.
idx = {}
{ 'hardship' => 'ukpf_hardship', 'aspiration' => 'ukpf_aspiration', 'dwphelp' => 'dwphelp', 'fireuk' => 'fireuk' }.each do |k, src|
  idx[k] = MONTHS.to_h { |m| b = R['ukpf_all'][m]; v = R[src][m]; [m, (b && b > 0 && v && !(src == "dwphelp" && m < "2019-06")) ? (v / b * 1000).round(2) : nil] }
end
yoy = ->(s) { s.to_h { |m, v| y, mo = m.split('-'); p = s["#{y.to_i - 1}-#{mo}"]; [m, (v && p && p > 0) ? ((v / p - 1) * 100) : nil] } }

def mmul(a, b) a.map { |r| b.transpose.map { |c| r.zip(c).sum { |x, y| x * y } } } end
def inv(m) n = m.size; a = m.map.with_index { |r, i| r + Array.new(n) { |j| i == j ? 1.0 : 0.0 } }
  n.times { |i| p = (i...n).max_by { |k| a[k][i].abs }; a[i], a[p] = a[p], a[i]; d = a[i][i]; a[i].map! { |x| x / d }
    n.times { |k| next if k == i; f = a[k][i]; a[k] = a[k].zip(a[i]).map { |x, y| x - f * y } } }
  a.map { |r| r[n..] } end
# OLS with Newey-West (HAC) standard errors; L = 12 months
def ols(y, xs, names, l = 12)
  n = y.size; x = xs.map { |r| [1.0] + r }; xt = x.transpose; xtxi = inv(mmul(xt, x))
  b = mmul(xtxi, mmul(xt, y.map { |v| [v] })).map(&:first); e = x.each_with_index.map { |r, i| y[i] - r.zip(b).sum { |a, c| a * c } }
  k = b.size; s = Array.new(k) { Array.new(k, 0.0) }
  (0..l).each { |lag| w = lag.zero? ? 1.0 : 1 - lag.to_f / (l + 1)
    (lag...n).each { |t| u = x[t].map { |v| v * e[t] }; v = x[t - lag].map { |q| q * e[t - lag] }
      k.times { |i| k.times { |j| s[i][j] += w * (u[i] * v[j] + (lag.zero? ? 0 : v[i] * u[j])) } } } }
  cov = mmul(mmul(xtxi, s), xtxi); my = y.sum / n; r2 = 1 - e.sum { |v| v * v } / y.sum { |v| (v - my)**2 }
  { n: n, r2: r2.round(3), adj_r2: (1 - (1 - r2) * (n - 1) / (n - k)).round(3),
    coefs: (['const'] + names).each_with_index.map { |nm, i| se = Math.sqrt(cov[i][i]); { name: nm, b: b[i].round(4), se: se.round(4), t: (b[i] / se).round(2) } },
    fitted: x.map { |r| r.zip(b).sum { |a, c| a * c }.round(3) } }
end
def corr(a, b) pr = a.zip(b).reject { |p, q| p.nil? || q.nil? }; return nil if pr.size < 12
  ma = pr.sum(&:first) / pr.size; mb = pr.sum(&:last) / pr.size
  (pr.sum { |p, q| (p - ma) * (q - mb) } / Math.sqrt(pr.sum { |p, _| (p - ma)**2 } * pr.sum { |_, q| (q - mb)**2 })).round(3) end

ECON = %w[cpi bank_rate unemp gdp_yoy wages]
out = { months: MONTHS, econ: ECON.to_h { |c| [c, MONTHS.map { |m| E[m][c] }] }, raw: R.transform_values { |s| MONTHS.map { |m| s[m] } }, models: {} }
out[:econ]['gdp_index'] = MONTHS.map { |m| E[m]['gdp_index'] }
idx.each do |k, s|
  ys = yoy.(s); ey = ECON.to_h { |c| [c, yoy.(MONTHS.to_h { |m| [m, E[m][c]] })] }
  rows = MONTHS.select { |m| s[m] && ECON.all? { |c| E[m][c] } && !(m >= '2020-03' && m <= '2021-06') } # drop COVID distortion window
  next if rows.size < 24
  full = MONTHS.select { |m| s[m] && ECON.all? { |c| E[m][c] } }
  m = { index: MONTHS.map { |mm| s[mm] }, fit_months: rows, ols: ols(rows.map { |mm| s[mm] }, rows.map { |mm| ECON.map { |c| E[mm][c] } }, ECON),
        ols_with_covid: ols(full.map { |mm| s[mm] }, full.map { |mm| ECON.map { |c| E[mm][c] } }, ECON).tap { |o| o.delete(:fitted) },
        corr_levels: ECON.to_h { |c| [c, corr(MONTHS.map { |mm| s[mm] }, MONTHS.map { |mm| E[mm][c] })] },
        # change-on-change: Reddit index YoY % vs year-on-year change (pp) in each indicator; avoids spurious trend correlation
        corr_changes: ECON.to_h { |c| [c, corr(MONTHS.map { |mm| ys[mm] }, MONTHS.map { |mm| y, mo = mm.split('-'); p = E["#{y.to_i - 1}-#{mo}"]; (E[mm][c] && p && p[c]) ? E[mm][c] - p[c] : nil })] },
        # lead/lag: corr(index_t, indicator_{t+k}); k>0 means Reddit moves first
        leadlag: %w[cpi unemp gdp_yoy].to_h { |c| [c, (-12..12).map { |kk| corr(MONTHS.map { |mm| s[mm] }, MONTHS.each_index.map { |i| j = i + kk; (j >= 0 && j < MONTHS.size) ? E[MONTHS[j]][c] : nil }) }] } }
  out[:models][k] = m
end
File.write('data/results.json', JSON.generate(out))
out[:models].each { |k, m| puts "== #{k}  R2=#{m[:ols][:r2]} adjR2=#{m[:ols][:adj_r2]} n=#{m[:ols][:n]}  (with covid R2=#{m[:ols_with_covid][:r2]})"
  m[:ols][:coefs].each { |c| puts "   #{c[:name].ljust(10)} b=#{c[:b].to_s.rjust(9)} t=#{c[:t]}" }
  puts "   levels  #{m[:corr_levels]}"; puts "   changes #{m[:corr_changes]}"
  m[:leadlag].each { |c, v| bi = v.each_with_index.reject { |x, _| x.nil? }.max_by { |x, _| x.abs }; puts "   leadlag #{c}: k=0 r=#{v[12]}, peak k=#{bi[1] - 12} r=#{bi[0]}" } }
