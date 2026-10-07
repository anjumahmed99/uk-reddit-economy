# Assembles index.html, a standalone page (served by GitHub Pages), from the template, findings text and results.
t = File.read('report_template.html'); txt = File.read('report_text.html')
v, c = txt.split('<!--CAVEATS-->'); v = v.sub('<!--VERDICTS-->', '')
page = t.sub('<!--VERDICTS-->', v).sub('<!--CAVEATS-->', c).sub('/*DATA*/', File.read('data/results.json'))
head, body = page.split('</style>', 2)
File.write('index.html', <<~HTML)
  <!doctype html>
  <html lang="en">
  <head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="Do UK money subreddits track GDP, inflation, Bank Rate and unemployment? Two models, 2016-2026.">
  #{head}</style>
  </head>
  <body>
  #{body}
  </body>
  </html>
HTML
puts File.size('index.html')
