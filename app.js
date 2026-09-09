'use strict';
document.querySelectorAll('[data-filter]').forEach(button => {
button.addEventListener('click', () => {
const task = button.dataset.filter;
document.querySelectorAll('[data-filter]').forEach(filter => {
const active = filter === button;
filter.classList.toggle('active', active);
filter.setAttribute('aria-pressed', String(active));
});
let count = 0;
document.querySelectorAll('.result-row').forEach(row => {
row.hidden = task !== 'all' && row.dataset.task !== task;
const control = row.querySelector('[data-details]');
document.getElementById(control.getAttribute('aria-controls')).hidden = true;
control.setAttribute('aria-expanded', 'false');
control.querySelector('.expand-icon').textContent = '+';
if (!row.hidden) count++;
});
document.getElementById('results-count').textContent = count + (count === 1 ? ' record' : ' records');
});
});
document.querySelectorAll('[data-details]').forEach(button => {
button.addEventListener('click', () => {
const opening = button.getAttribute('aria-expanded') !== 'true';
button.setAttribute('aria-expanded', String(opening));
button.querySelector('.expand-icon').textContent = opening ? '−' : '+';
document.getElementById(button.getAttribute('aria-controls')).hidden = !opening;
});
});
