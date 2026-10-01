const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

// The classroom's school systems, run without a browser.
const scene = path.join(__dirname, '../assets/text_library/scene');
const context = {window: {}, console, setTimeout, document: {getElementById: () => null}};
vm.createContext(context);
vm.runInContext(fs.readFileSync(path.join(scene, 'classroom.js'), 'utf8'), context, {filename: 'classroom.js'});
const {COUNTRIES, yearsFor, languageOf} = context.window.LibraryClassroom;

const school = (country, name) => COUNTRIES.find(c => c.name === country).schools.find(s => s.name === name);

test('a level only offers the years it runs through', () => {
  const vo = school('Nederland', 'Middelbare school');
  assert.deepEqual([...yearsFor(vo, 'havo')], ['Leerjaar 1', 'Leerjaar 2', 'Leerjaar 3', 'Leerjaar 4', 'Leerjaar 5']);
  assert.equal(yearsFor(vo, 'vmbo-kader').length, 4);
  assert.equal(yearsFor(vo, 'vwo (gymnasium)').length, 6);
  assert.equal(yearsFor(vo, '').length, 6, 'no level picked yet shows every year');
  assert.deepEqual([...yearsFor(school('United Kingdom', 'Secondary school'), 'GCSE Higher')], ['Year 10', 'Year 11']);
  assert.equal(yearsFor(school('France', 'Lycée'), 'Générale').length, 3, 'years without a number are always offered');
});

test('every country name is one the server accepts', () => {
  // cleanClassroomCountry in server/lib/classroom.dart.
  const ok = /^[\p{L}\p{M} .,'()-]+$/u;
  for (const c of COUNTRIES) {
    assert.ok(c.name.length >= 2 && c.name.length <= 56 && ok.test(c.name), c.name);
  }
});

test('every school has years, and every level a last year inside them', () => {
  for (const c of COUNTRIES) {
    for (const s of c.schools) {
      assert.ok(s.years.length, `${c.name} ${s.name}`);
      for (const [name, last] of s.levels || []) {
        assert.ok(Number.isInteger(last), `${s.name} ${name}`);
        assert.ok(yearsFor(s, name).length, `${s.name} ${name} offers no year`);
      }
    }
  }
});

test("the classroom speaks the language of the reader's school country", () => {
  assert.equal(languageOf('Nederland'), 'nl');
  assert.equal(languageOf('België (Vlaanderen)'), 'nl');
  assert.equal(languageOf('France'), 'fr');
  assert.equal(languageOf('España'), 'es');
  assert.equal(languageOf('United States'), 'en');
  assert.equal(languageOf('Deutschland'), 'de', 'not an app language, so the app language is used');
  assert.equal(languageOf('  Netherlands'), 'nl', 'typed under somewhere else');
  assert.equal(languageOf('中国'), 'zh');
  assert.equal(languageOf('México'), 'es');
  assert.equal(languageOf('Japan'), null);
  assert.equal(languageOf(null), null);
  for (const c of COUNTRIES) assert.ok(c.lang, `${c.name} has no language`);
});
