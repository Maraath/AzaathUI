// descartável: conserta as linhas com escapes perdidos em dungeonquests.js
const fs = require("fs");
const f = __dirname + "/../dungeonquests.js";
let L = fs.readFileSync(f, "utf8").split("\n");
const find = (pre) => L.findIndex((l) => l.includes(pre));
let i = find("for (const m of src.matchAll(new RegExp(");
let j = find("const mm = /^(");
L.splice(i, j - i + 1,
  "    for (const m of src.matchAll(new RegExp('R\\\\(\"' + kind + '\",[^\\\\[]*\\\\[\\\\[([\\\\s\\\\S]*?)\\\\]\\\\]', \"g\"))) {",
  "      for (const line of m[1].split(/\\r?\\n/)) {",
  "        const mm = /^(\\d+)\\t'([^;]*)/.exec(line);");
i = find('for (const line of fs.readFileSync(QUESTDB, "utf8").split(');
j = find("if (f.length < 20 ||");
L.splice(i, j - i + 1,
  '    for (const line of fs.readFileSync(QUESTDB, "utf8").split(/\\r?\\n/)) {',
  '      const f = line.split("\\t");',
  "      if (f.length < 20 || !/^\\d+$/.test(f[0])) continue;");
fs.writeFileSync(f, L.join("\n"));
