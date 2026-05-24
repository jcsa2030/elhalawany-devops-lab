const fs = require('fs');
const path = require('path');

const inputFile = path.join(__dirname, '..', 'compliance', 'nist', 'nist-csf-2.0.json');
const outputFile = path.join(__dirname, '..', 'compliance', 'nist', 'NIST-CSF.csv');

const raw = fs.readFileSync(inputFile, 'utf8');
const data = JSON.parse(raw);

function escapeCsv(value) {
    if (value === null || value === undefined) return '';
    const str = String(value).replace(/"/g, '""');
    return `"${str}"`;
}

const rows = [];
rows.push(['id', 'title', 'text', 'function', 'category'].map(escapeCsv).join(','));

function walk(obj, parent = {}) {
    if (Array.isArray(obj)) {
        obj.forEach(item => walk(item, parent));
        return;
    }

    if (obj && typeof obj === 'object') {
        const id = obj.id || obj.identifier || obj.name || '';
        const title = obj.title || obj.name || '';
        const text = obj.text || obj.description || obj.statement || '';

        if (id || title || text) {
            rows.push([
                id,
                title,
                text,
                parent.function || '',
                parent.category || ''
            ].map(escapeCsv).join(','));
        }

        const nextParent = { ...parent };

        if (String(id).startsWith('GV') || String(id).startsWith('ID') || String(id).startsWith('PR') || String(id).startsWith('DE') || String(id).startsWith('RS') || String(id).startsWith('RC')) {
            nextParent.function = String(id).split('.')[0];
            if (String(id).includes('.')) nextParent.category = String(id).split('-')[0];
        }

        Object.values(obj).forEach(value => walk(value, nextParent));
    }
}

walk(data);

fs.writeFileSync(outputFile, rows.join('\n'));
console.log('Created:', outputFile);
console.log('Rows:', rows.length - 1);
