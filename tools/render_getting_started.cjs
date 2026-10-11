// Render vector callouts around real, unchanged Partsmith screenshot pixels.
// Usage: node tools/render_getting_started.cjs (requires sharp on NODE_PATH).
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');
const root = path.resolve(__dirname, '../docs/images/getting-started');
const escape = s => String(s).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('"', '&quot;');
const figures = JSON.parse(fs.readFileSync(path.join(root, 'callouts.json'), 'utf8'));
(async () => {
  for (const fig of figures) {
    const rawPath = path.join(root, 'raw', fig.file + '.png');
    if (!fs.existsSync(rawPath)) throw new Error(`Missing capture: ${rawPath}`);
    const bytes = fs.readFileSync(rawPath);
    const meta = await sharp(bytes).metadata();
    const [cx, cy, cw, ch] = fig.crop;
    if (cx < 0 || cy < 0 || cx + cw > meta.width || cy + ch > meta.height) throw new Error(`Crop exceeds capture: ${fig.file}`);
    const width = fig.width || 1440, scale = width / cw, top = 68;
    const photoHeight = Math.round(ch * scale), footer = 30 + 48 * Math.ceil(fig.callouts.length / 2);
    const height = Math.ceil(top + photoHeight + footer);
    const px = x => (x - cx) * scale, py = y => top + (y - cy) * scale;
    const vectors = fig.callouts.map((c, i) => {
      const [bx, by, tx, ty] = c.arrow;
      const x = px(bx), y = py(by), dx = px(tx), dy = py(ty);
      return `<line x1="${x}" y1="${y}" x2="${dx}" y2="${dy}" stroke="#fff" stroke-width="8"/>
        <line x1="${x}" y1="${y}" x2="${dx}" y2="${dy}" stroke="#d64b00" stroke-width="3" marker-end="url(#arrow)"/>
        <circle cx="${x}" cy="${y}" r="19" fill="#d64b00" stroke="#fff" stroke-width="3"/>
        <text x="${x}" y="${y + 7}" text-anchor="middle" fill="#fff" font-size="22" font-weight="700">${i + 1}</text>`;
    }).join('');
    const legends = fig.callouts.map((c, i) => {
      const x = 28 + (i % 2) * 710, y = top + photoHeight + 37 + Math.floor(i / 2) * 48;
      return `<circle cx="${x + 18}" cy="${y - 7}" r="16" fill="#d64b00"/>
        <text x="${x + 18}" y="${y}" text-anchor="middle" fill="#fff" font-size="19" font-weight="700">${i + 1}</text>
        <text x="${x + 45}" y="${y}" fill="#17233b" font-size="22">${escape(c.label)}</text>`;
    }).join('');
    const wrapper = imageHref => `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
      <defs><clipPath id="shot"><rect x="0" y="${top}" width="${width}" height="${photoHeight}"/></clipPath><marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="9" markerHeight="9" orient="auto-start-reverse"><path d="M 0 0 L 10 5 L 0 10 z" fill="#d64b00"/></marker></defs>
      <rect width="100%" height="${top}" fill="#f3f6fb"/>
      <rect y="${top + photoHeight}" width="100%" height="${footer}" fill="#f3f6fb"/>
      <g font-family="Helvetica, Arial, sans-serif"><text x="28" y="44" font-size="28" font-weight="700" fill="#17233b">${escape(fig.title)}</text>
      ${imageHref ? `<g clip-path="url(#shot)"><image x="${-cx * scale}" y="${top - cy * scale}" width="${meta.width * scale}" height="${meta.height * scale}" href="${imageHref}" xlink:href="${imageHref}"/></g>` : ''}
      ${vectors}${legends}</g></svg>`;
    fs.writeFileSync(path.join(root, fig.file + '.svg'), wrapper('raw/' + fig.file + '.png'));
    // Composite the real pixels explicitly. Some SVG renderers disable embedded
    // images; using an image-free vector overlay avoids blank screenshot output.
    const shot = await sharp(bytes).extract({left:cx, top:cy, width:cw, height:ch})
      .resize(width, photoHeight).png().toBuffer();
    await sharp({create:{width, height, channels:4, background:'#f3f6fb'}})
      .composite([{input:shot, left:0, top}, {input:Buffer.from(wrapper(null)), left:0, top:0}])
      .png().toFile(path.join(root, fig.file + '.png'));
    console.log(`${fig.file}: ${width}×${height}`);
  }
})().catch(error => { console.error(error.message); process.exitCode = 1; });
