const express = require('express');
const client = require('prom-client');
const dotenv = require('dotenv');
const helmet = require('helmet');
const morgan = require('morgan');
const cors = require('cors');
const { Pool } = require('pg');
const { createClient } = require('redis');
const fs = require('fs');
const path = require('path');
const csv = require('csv-parser');

const nodeEnv = process.env.NODE_ENV || 'dev';

dotenv.config({
    path: `.env.${nodeEnv}`
});

const app = express();
const register = new client.Registry();

client.collectDefaultMetrics({
    register
});

const httpRequestCounter = new client.Counter({
    name: 'devsecops_http_requests_total',
    help: 'Total HTTP requests',
    labelNames: ['method', 'route', 'status']
});

register.registerMetric(httpRequestCounter);


/* Enterprise Security Governance Metrics */
const securityComplianceScore = new client.Gauge({
    name: 'security_compliance_score',
    help: 'Overall enterprise security compliance score'
});

const securityReleaseSuccess = new client.Gauge({
    name: 'security_release_success_total',
    help: 'Release success indicator'
});

const securityUatSuccess = new client.Gauge({
    name: 'security_uat_success_total',
    help: 'UAT deployment success indicator'
});

const securityProdSuccess = new client.Gauge({
    name: 'security_production_success_total',
    help: 'Production deployment success indicator'
});

const securityZapFailNew = new client.Gauge({
    name: 'security_zap_fail_new',
    help: 'OWASP ZAP new failed findings'
});

const securityZapWarnNew = new client.Gauge({
    name: 'security_zap_warn_new',
    help: 'OWASP ZAP new warning findings'
});

const securitySonarGate = new client.Gauge({
    name: 'security_sonar_quality_gate_pass',
    help: 'SonarQube Quality Gate pass indicator'
});

const securityOpaGate = new client.Gauge({
    name: 'security_opa_policy_gate_pass',
    help: 'OPA Policy Gate pass indicator'
});

const securityGitleaksPass = new client.Gauge({
    name: 'security_gitleaks_pass',
    help: 'GitLeaks scan pass indicator'
});

register.registerMetric(securityComplianceScore);
register.registerMetric(securityReleaseSuccess);
register.registerMetric(securityUatSuccess);
register.registerMetric(securityProdSuccess);
register.registerMetric(securityZapFailNew);
register.registerMetric(securityZapWarnNew);
register.registerMetric(securitySonarGate);
register.registerMetric(securityOpaGate);
register.registerMetric(securityGitleaksPass);

securityComplianceScore.set(100);
securityReleaseSuccess.set(1);
securityUatSuccess.set(1);
securityProdSuccess.set(1);
securityZapFailNew.set(0);
securityZapWarnNew.set(0);
securitySonarGate.set(1);
securityOpaGate.set(1);
securityGitleaksPass.set(1);

const PORT = process.env.PORT || 3000;
const APP_NAME = process.env.APP_NAME || 'Elhalawany DevOps Lab';
const APP_ENV = process.env.APP_ENV || nodeEnv;
const APP_COLOR = process.env.APP_COLOR || '#38bdf8';
const APP_MESSAGE = process.env.APP_MESSAGE || 'Multi-Tier DevSecOps Application';

app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(morgan(APP_ENV === 'production' ? 'combined' : 'dev'));

app.use((req, res, next) => {

    res.on('finish', () => {

        httpRequestCounter.inc({
            method: req.method,
            route: req.path,
            status: res.statusCode
        });

    });

    next();
});

/* PostgreSQL */
const pool = new Pool({
    host: process.env.DB_HOST || 'postgres',
    port: Number(process.env.DB_PORT || 5432),
    database: process.env.DB_NAME || 'devopsdb',
    user: process.env.DB_USER || 'devsecops',
    password: process.env.DB_PASSWORD || 'devopspassword'
});

/* Redis */
let redisClient = null;

async function initRedis() {
    try {
        redisClient = createClient({
            socket: {
                host: process.env.REDIS_HOST || 'redis',
                port: Number(process.env.REDIS_PORT || 6379)
            }
        });

        redisClient.on('error', (err) => {
            console.error('Redis Error:', err.message);
        });

        await redisClient.connect();
        console.log('Redis connected successfully');
    } catch (error) {
        console.error('Redis startup connection failed:', error.message);
    }
}

initRedis();

/* Dashboard Metrics */
const dashboardData = {
    dev: {
        docker: 90,
        nginx: 85,
        database: 75,
        redis: 70,
        jenkins: 65,
        security: 60,
        nist: 70,
        owasp: 70,
        kubernetes: 40
    },
    test: {
        docker: 95,
        nginx: 90,
        database: 85,
        redis: 80,
        jenkins: 75,
        security: 75,
        nist: 80,
        owasp: 80,
        kubernetes: 60
    },
    security: {
        docker: 95,
        nginx: 90,
        database: 85,
        redis: 85,
        jenkins: 85,
        security: 95,
        nist: 90,
        owasp: 95,
        kubernetes: 70
    },
    production: {
        docker: 100,
        nginx: 95,
        database: 95,
        redis: 90,
        jenkins: 90,
        security: 90,
        nist: 90,
        owasp: 90,
        kubernetes: 85
    }
};

const currentMetrics = dashboardData[APP_ENV] || dashboardData.dev;

/* Generic CSV Reader */
function readCsvFile(relativePath, label) {
    return new Promise((resolve, reject) => {
        const results = [];
        const filePath = path.join(__dirname, relativePath);

        if (!fs.existsSync(filePath)) {
            return reject(new Error(`${label} CSV file not found at ${filePath}`));
        }

        fs.createReadStream(filePath)
            .pipe(csv())
            .on('data', (data) => results.push(data))
            .on('end', () => resolve(results))
            .on('error', reject);
    });
}

/* CSV Helpers */
function readNistCsv() {
    return readCsvFile(path.join('compliance', 'nist', 'NIST-CSF.csv'), 'NIST');
}

function readOwaspCsv() {
    return readCsvFile(path.join('compliance', 'owasp', 'OWASP-Top10.csv'), 'OWASP');
}
/* Health API */
app.get('/health', (req, res) => {
    res.json({
        status: 'UP',
        application: APP_NAME,
        environment: APP_ENV,
        port: PORT,
        uptime_seconds: process.uptime(),
        timestamp: new Date().toISOString()
    });
});

/* PostgreSQL Health API */
app.get('/api/db-health', async (req, res) => {
    try {
        const result = await pool.query('SELECT NOW()');

        res.json({
            status: 'UP',
            database: 'PostgreSQL',
            message: 'Database connection successful',
            db_time: result.rows[0].now,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            status: 'DOWN',
            database: 'PostgreSQL',
            message: 'Database connection failed',
            error: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

/* Redis Health API */
app.get('/api/redis-health', async (req, res) => {
    try {
        if (!redisClient) {
            return res.status(500).json({
                status: 'DOWN',
                cache: 'Redis',
                message: 'Redis client is not initialized',
                timestamp: new Date().toISOString()
            });
        }

        if (!redisClient.isOpen) {
            await redisClient.connect();
        }

        await redisClient.set('lab_status', 'Redis cache is working');
        const value = await redisClient.get('lab_status');

        res.json({
            status: 'UP',
            cache: 'Redis',
            message: 'Redis connection successful',
            test_value: value,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            status: 'DOWN',
            cache: 'Redis',
            message: 'Redis connection failed',
            error: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

/* NIST Controls API */
app.get('/api/nist-controls', async (req, res) => {
    try {
        const controls = await readNistCsv();

        res.json({
            status: 'UP',
            framework: 'NIST CSF',
            file: 'compliance/nist/NIST-CSF.csv',
            total_controls: controls.length,
            controls,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            status: 'ERROR',
            framework: 'NIST CSF',
            message: 'Failed to read NIST CSV file',
            error: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

/* NIST Summary API */
app.get('/api/nist-summary', async (req, res) => {
    try {
        const controls = await readNistCsv();

        res.json({
            status: 'UP',
            framework: 'NIST CSF',
            file: 'compliance/nist/NIST-CSF.csv',
            total_controls: controls.length,
            sample_controls: controls.slice(0, 5),
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            status: 'ERROR',
            framework: 'NIST CSF',
            message: 'Failed to summarize NIST CSV file',
            error: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

/* OWASP Top 10 API */
app.get('/api/owasp-top10', async (req, res) => {
    try {
        const items = await readOwaspCsv();

        res.json({
            status: 'UP',
            framework: 'OWASP Top 10',
            file: 'compliance/owasp/OWASP-Top10.csv',
            total_items: items.length,
            items,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            status: 'ERROR',
            framework: 'OWASP Top 10',
            message: 'Failed to read OWASP CSV file',
            error: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

/* OWASP Summary API */
app.get('/api/owasp-summary', async (req, res) => {
    try {
        const items = await readOwaspCsv();

        res.json({
            status: 'UP',
            framework: 'OWASP Top 10',
            file: 'compliance/owasp/OWASP-Top10.csv',
            total_items: items.length,
            sample_items: items.slice(0, 5),
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            status: 'ERROR',
            framework: 'OWASP Top 10',
            message: 'Failed to summarize OWASP CSV file',
            error: error.message,
            timestamp: new Date().toISOString()
        });
    }
});
/* Dashboard API */
app.get('/api/dashboard', (req, res) => {
    res.json({
        application: APP_NAME,
        environment: APP_ENV,
        architecture: {
            entry_tier: 'NGINX Reverse Proxy',
            application_tier: 'Node.js + Express',
            database_tier: 'PostgreSQL',
            cache_tier: 'Redis',
            compliance_reference: 'NIST CSF API',
            security_reference: 'OWASP Top 10 API',
            security_tier: 'Helmet + CORS + Morgan'
        },
        security_frameworks: [
            'NIST CSF',
            'OWASP Top 10'
        ],
        metrics: currentMetrics,
        available_routes: [
            '/',
            '/health',
            '/api/dashboard',
            '/api/db-health',
            '/api/redis-health',
            '/api/nist-controls',
            '/api/nist-summary',
            '/api/owasp-top10',
            '/api/owasp-summary',
            '/about'
        ],
        status: 'Running',
        timestamp: new Date().toISOString()
    });
});

app.get('/api/customers', (req, res) => {
    res.json({
        status: 'success',
        count: 3,
        customers: [
            {
                id: 1,
                name: 'Customer One',
                segment: 'Enterprise',
                status: 'active'
            },
            {
                id: 2,
                name: 'Customer Two',
                segment: 'SME',
                status: 'active'
            },
            {
                id: 3,
                name: 'Customer Three',
                segment: 'Startup',
                status: 'inactive'
            }
        ],
        timestamp: new Date().toISOString()
    });
});


/* Simple Home Page */
app.get('/', (req, res) => {
    res.send(`
<!DOCTYPE html>
<html>
<head>
<title>${APP_NAME}</title>
<style>
body {
    background: #0f172a;
    color: white;
    font-family: Arial, Helvetica, sans-serif;
    padding: 40px;
}
.card {
    max-width: 1100px;
    margin: auto;
    background: #1e293b;
    padding: 35px;
    border-radius: 18px;
}
h1, h2 {
    color: ${APP_COLOR};
}
a {
    display: inline-block;
    margin: 8px;
    padding: 12px 18px;
    background: ${APP_COLOR};
    color: #020617;
    border-radius: 8px;
    text-decoration: none;
    font-weight: bold;
}
p {
    color: #cbd5e1;
    line-height: 1.7;
}
</style>
</head>
<body>
<div class="card">
    <h1>${APP_NAME}</h1>
    <h2>Environment: ${APP_ENV.toUpperCase()}</h2>
    <p>${APP_MESSAGE}</p>
    <p>Browser → NGINX → Node.js → PostgreSQL + Redis + NIST API + OWASP API</p>

    <a href="/health">Health</a>
    <a href="/api/dashboard">Dashboard</a>
    <a href="/api/db-health">PostgreSQL</a>
    <a href="/api/redis-health">Redis</a>
    <a href="/api/nist-summary">NIST Summary</a>
    <a href="/api/nist-controls">NIST Controls</a>
    <a href="/api/owasp-summary">OWASP Summary</a>
    <a href="/api/owasp-top10">OWASP Top 10</a>
    <a href="/about">About</a>
</div>
</body>
</html>
    `);
});

/* About Page */
app.get('/about', (req, res) => {
    res.send(`
<!DOCTYPE html>
<html>
<head>
<title>About</title>
<style>
body {
    background: #0f172a;
    color: white;
    font-family: Arial, Helvetica, sans-serif;
    padding: 50px;
}
.card {
    max-width: 900px;
    margin: auto;
    background: #1e293b;
    padding: 40px;
    border-radius: 18px;
}
h1 {
    color: ${APP_COLOR};
}
a {
    color: ${APP_COLOR};
    font-weight: bold;
}
</style>
</head>
<body>
<div class="card">
    <h1>About ${APP_NAME}</h1>
    <p>This is a multi-tier DevSecOps lab application.</p>
    <p><b>Architecture:</b> Browser → NGINX → Node.js → PostgreSQL + Redis + NIST API + OWASP API</p>
    <p><b>Environment:</b> ${APP_ENV.toUpperCase()}</p>
    <a href="/">Back to Home</a>
</div>
</body>
</html>
    `);
});

app.get('/metrics', async (req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
});

/* 404 Handler */
app.use((req, res) => {
    res.status(404).json({
        status: 'NOT_FOUND',
        message: 'Route not found',
        path: req.originalUrl,
        available_routes: [
            '/',
            '/health',
            '/api/dashboard',
            '/api/db-health',
            '/api/redis-health',
            '/api/nist-controls',
            '/api/nist-summary',
            '/api/owasp-top10',
            '/api/owasp-summary',
            '/api/customers',
            '/about'
        ]
    });
});


/* Start Server */
app.listen(PORT, () => {
    console.log('Server running on port ' + PORT);
    console.log('Environment: ' + APP_ENV);
    console.log('Redis route enabled: /api/redis-health');
    console.log('NIST controls route enabled: /api/nist-controls');
    console.log('NIST summary route enabled: /api/nist-summary');
    console.log('OWASP route enabled: /api/owasp-top10');
    console.log('OWASP summary route enabled: /api/owasp-summary');
});