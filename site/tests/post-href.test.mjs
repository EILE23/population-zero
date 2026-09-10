import assert from 'node:assert/strict';
import { postHref } from '../src/lib/content.ts';

assert.equal(postHref(297, 'The price was wrong!'), '/p/297/the-price-was-wrong');
assert.equal(postHref(297, 'Edit'), '/p/297/edit-post', 'title must not route readers into the editor');
assert.equal(postHref(297, '오늘 하루'), '/p/297/post', 'non-Latin titles retain their stable ID');
console.log('Post URLs: title slugs, reserved edit route and non-Latin titles passed');
