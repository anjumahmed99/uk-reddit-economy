# Merge ONS + Bank of England series into one monthly CSV (2016-01 onward).
require 'json'; require 'date'
M = %w[JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC]
def ons_monthly(f); JSON.parse(File.read(f))['months'].to_h { |m| y, mo = m['date'].split; ["#{y}-%02d" % (M.index(mo) + 1), m['value'].to_f] }; end
s = {
  'gdp_index' => ons_monthly('data/raw_gdp_index.json'),
  'cpi'       => ons_monthly('data/raw_cpi.json'),
  'unemp'     => ons_monthly('data/raw_unemp.json'),
  'wages'     => ons_monthly('data/raw_wages.json'),
}
# Quarterly GDP growth, repeated across each month of its quarter
s['gdp_qoq'] = JSON.parse(File.read('data/raw_gdp_qoq.json'))['quarters'].each_with_object({}) do |q, h|
  y, qq = q['date'].split; b = (qq[1].to_i - 1) * 3
  3.times { |i| h["#{y}-%02d" % (b + i + 1)] = q['value'].to_f }
end
s['bank_rate'] = File.readlines('data/raw_bankrate.csv').drop(1).to_h { |l| d, v = l.strip.split(','); [Date.parse(d).strftime('%Y-%m'), v.to_f] }
# GDP year-on-year growth from the monthly index
s['gdp_yoy'] = s['gdp_index'].to_h { |k, v| y, m = k.split('-'); p = s['gdp_index']["#{y.to_i - 1}-#{m}"]; [k, p && ((v / p - 1) * 100).round(2)] }
cols = %w[gdp_index gdp_yoy gdp_qoq cpi bank_rate unemp wages]
months = s.values.flat_map(&:keys).uniq.select { |k| k >= '2016-01' && k <= '2026-09' }.sort
File.open('data/uk_econ_monthly.csv', 'w') { |f| f.puts(['month', *cols].join(',')); months.each { |m| f.puts([m, *cols.map { |c| s[c][m] }].join(',')) } }
puts months.size, File.readlines('data/uk_econ_monthly.csv').values_at(0, 1, 50, -3, -1)
