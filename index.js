const express = require('express');
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

const PORT = process.env.PORT || 3000;
const APP_NAME = process.env.APP_NAME || 'Elhalawany DevOps Lab';
const APP_ENV = process.env.APP_ENV || nodeEnv;
const APP_COLOR = process.env.APP_COLOR || '#38bdf8';
const APP_MESSAGE = process.env.APP_MESSAGE || 'Multi-Tier DevOps Application';

app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(morgan(APP_ENV === 'production' ? 'combined' : 'dev'));

/* PostgreSQL */
const pool = new Pool({
    host: process.env.DB_HOST || 'postgres',
    port: Number(process.env.DB_PORT || 5432),
    database: process.env.DB_NAME || 'devopsdb',
    user: process.env.DB_USER || 'devopsuser',
    password: process.env.DB_PASSWORD || 'devopspassword'
});

/* Redis - Safe Startup */
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

/* Dashboard Data */
const dashboardData = {
    dev: {
        docker: 90,
        nginx: 85,
        database: 75,
        redis: 70,
        jenkins: 65,
        security: 60,
        nist: 70,
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
        kubernetes: 60
    },
    production: {
        docker: 100,
        nginx: 95,
        database: 95,
        redis: 90,
        jenkins: 90,
        security: 90,
        nist: 90,
        kubernetes: 85
    }
};

const currentMetrics = dashboardData[APP_ENV] || dashboardData.dev;

/* Helper: Read NIST CSV */
function readNistCsv() {
    return new Promise((resolve, reject) => {
        const results = [];
        const filePath = path.join(__dirname, 'compliance', 'nist', 'NIST-CSF.csv');

        if (!fs.existsSync(filePath)) {
            return reject(new Error(`NIST CSV file not found at ${filePath}`));
        }

        fs.createReadStream(filePath)
            .pipe(csv())
            .on('data', (data) => results.push(data))
            .on('end', () => resolve(results))
            .on('error', reject);
    });
}

/* Home Page */
app.get('/', (req, res) => {
    res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>${APP_NAME}</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0">

<style>
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
    font-family: Arial, Helvetica, sans-serif;
}

body {
    background: #0f172a;
    color: white;
}

header {
    background: #020617;
    padding: 20px 60px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1px solid #1e293b;
}

.logo {
    font-size: 26px;
    font-weight: bold;
    color: ${APP_COLOR};
}

nav a {
    color: white;
    text-decoration: none;
    margin-left: 18px;
    font-weight: bold;
}

nav a:hover {
    color: ${APP_COLOR};
}

.hero {
    min-height: 80vh;
    display: grid;
    grid-template-columns: 1.2fr 1fr;
    gap: 40px;
    align-items: center;
    padding: 70px 60px;
    background: linear-gradient(135deg, #020617, #0f172a, #1e293b);
}

.hero h1 {
    font-size: 55px;
    color: ${APP_COLOR};
    margin-bottom: 20px;
}

.hero p {
    font-size: 21px;
    color: #cbd5e1;
    line-height: 1.8;
    margin-bottom: 30px;
}

.badge {
    display: inline-block;
    background: ${APP_COLOR};
    color: #020617;
    padding: 10px 18px;
    border-radius: 30px;
    font-weight: bold;
    margin-bottom: 20px;
}

.btn {
    display: inline-block;
    background: ${APP_COLOR};
    color: #020617;
    padding: 15px 28px;
    border-radius: 10px;
    text-decoration: none;
    font-weight: bold;
    margin-right: 10px;
    margin-bottom: 10px;
}

.hero img {
    width: 100%;
    border-radius: 20px;
}

.section {
    padding: 70px 60px;
}

.section-dark {
    background: #111827;
}

h2 {
    text-align: center;
    color: ${APP_COLOR};
    font-size: 38px;
    margin-bottom: 40px;
}

.grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
    gap: 25px;
}

.card {
    background: #1e293b;
    padding: 30px;
    border-radius: 16px;
    border: 1px solid #334155;
}

.card h3 {
    color: ${APP_COLOR};
    margin-bottom: 15px;
}

.card p {
    color: #cbd5e1;
    line-height: 1.7;
    margin-bottom: 8px;
}

.progress-box {
    margin-bottom: 22px;
}

.progress-box span {
    display: flex;
    justify-content: space-between;
    margin-bottom: 8px;
    color: #cbd5e1;
}

.progress {
    width: 100%;
    height: 13px;
    background: #334155;
    border-radius: 20px;
    overflow: hidden;
}

.progress div {
    height: 100%;
    background: linear-gradient(90deg, ${APP_COLOR}, #22c55e);
}

footer {
    text-align: center;
    padding: 25px;
    background: #020617;
    color: #94a3b8;
}

@media(max-width: 850px) {
    header {
        flex-direction: column;
        gap: 15px;
        padding: 20px;
    }

    nav a {
        margin: 0 8px;
        font-size: 14px;
    }

    .hero {
        grid-template-columns: 1fr;
        padding: 45px 25px;
        text-align: center;
    }

    .hero h1 {
        font-size: 38px;
    }

    .section {
        padding: 45px 25px;
    }
}
</style>
</head>

<body>

<header>
    <div class="logo">${APP_NAME}</div>
    <nav>
        <a href="/">Home</a>
        <a href="/health">Health</a>
        <a href="/api/dashboard">Dashboard</a>
        <a href="/api/db-health">PostgreSQL</a>
        <a href="/api/redis-health">Redis</a>
        <a href="/api/nist-controls">NIST</a>
        <a href="/about">About</a>
    </nav>
</header>

<section class="hero">
    <div>
        <span class="badge">Environment: ${APP_ENV.toUpperCase()}</span>
        <h1>Enterprise Multi-Tier DevOps Architecture</h1>
        <p>${APP_MESSAGE}</p>
        <p>
            Browser → NGINX → Node.js Express → PostgreSQL + Redis + NIST Controls API
        </p>
        <a class="btn" href="/api/db-health">Check PostgreSQL</a>
        <a class="btn" href="/api/redis-health">Check Redis</a>
        <a class="btn" href="/api/nist-controls">View NIST Controls</a>
    </div>

    <div>
        <img src="https://images.unsplash.com/photo-1558494949-ef010cbdcc31?q=80&w=1200&auto=format&fit=crop" alt="Data Center">
    </div>
</section>

<section class="section section-dark">
    <h2>Application Tiers</h2>

    <div class="grid">
        <div class="card">
            <h3>NGINX Reverse Proxy</h3>
            <p>Acts as the entry point and forwards requests to Node.js.</p>
        </div>

        <div class="card">
            <h3>Node.js Backend</h3>
            <p>Runs the Express application and exposes APIs.</p>
        </div>

        <div class="card">
            <h3>PostgreSQL Database</h3>
            <p>Stores application data in a persistent database tier.</p>
        </div>

        <div class="card">
            <h3>Redis Cache</h3>
            <p>Provides caching and fast key-value storage.</p>
        </div>

        <div class="card">
            <h3>NIST Controls API</h3>
            <p>Reads NIST CSV controls from the project and exposes them through REST API.</p>
        </div>
    </div>
</section>

<section class="section">
    <h2>DevOps Dashboard</h2>

    <div class="grid">
        <div class="card">
            <h3>Pipeline Maturity</h3>

            <div class="progress-box">
                <span><b>Docker</b><b>${currentMetrics.docker}%</b></span>
                <div class="progress"><div style="width:${currentMetrics.docker}%"></div></div>
            </div>

            <div class="progress-box">
                <span><b>NGINX</b><b>${currentMetrics.nginx}%</b></span>
                <div class="progress"><div style="width:${currentMetrics.nginx}%"></div></div>
            </div>

            <div class="progress-box">
                <span><b>PostgreSQL</b><b>${currentMetrics.database}%</b></span>
                <div class="progress"><div style="width:${currentMetrics.database}%"></div></div>
            </div>

            <div class="progress-box">
                <span><b>Redis</b><b>${currentMetrics.redis}%</b></span>
                <div class="progress"><div style="width:${currentMetrics.redis}%"></div></div>
            </div>

            <div class="progress-box">
                <span><b>Jenkins</b><b>${currentMetrics.jenkins}%</b></span>
                <div class="progress"><div style="width:${currentMetrics.jenkins}%"></div></div>
            </div>

            <div class="progress-box">
                <span><b>Security Scan</b><b>${currentMetrics.security}%</b></span>
                <div class="progress"><div style="width:${currentMetrics.security}%"></div></div>
            </div>

            <div class="progress-box">
                <span><b>NIST API</b><b>${currentMetrics.nist}%</b></span>
                <div class="progress"><div style="width:${currentMetrics.nist}%"></div></div>
            </div>
        </div>

        <div class="card">
            <h3>System Status</h3>
            <p><b>Application:</b> ${APP_NAME}</p>
            <p><b>Environment:</b> ${APP_ENV}</p>
            <p><b>Node.js:</b> Running</p>
            <p><b>NGINX:</b> Enabled</p>
            <p><b>PostgreSQL API:</b> /api/db-health</p>
            <p><b>Redis API:</b> /api/redis-health</p>
            <p><b>NIST API:</b> /api/nist-controls</p>
        </div>
    </div>
</section>

<footer>
    © 2026 Elhalawany Multi-Tier DevOps Lab | Node.js, Express, NGINX, PostgreSQL, Redis, Docker, NIST
</footer>

</body>
</html>
    `);
});

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
            controls
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

        const sample = controls.slice(0, 5);

        res.json({
            status: 'UP',
            framework: 'NIST CSF',
            total_controls: controls.length,
            sample_controls: sample,
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
            compliance_reference: 'NIST CSV API',
            security_tier: 'Helmet + CORS + Morgan'
        },
        metrics: currentMetrics,
        available_routes: [
            '/',
            '/health',
            '/api/dashboard',
            '/api/db-health',
            '/api/redis-health',
            '/api/nist-controls',
            '/api/nist-summary',
            '/about'
        ],
        status: 'Running',
        timestamp: new Date().toISOString()
    });
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
    font-family: Arial;
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
    <p>This is a multi-tier DevOps lab application.</p>
    <p><b>Architecture:</b> Browser → NGINX → Node.js → PostgreSQL + Redis + NIST CSV API</p>
    <p><b>Environment:</b> ${APP_ENV.toUpperCase()}</p>
    <a href="/">Back to Home</a>
</div>
</body>
</html>
    `);
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
            '/about'
        ]
    });
});

/* Start Server */
app.listen(PORT, () => {
    console.log('Server running on port ' + PORT);
    console.log('Environment: ' + APP_ENV);
    console.log('Redis route enabled: /api/redis-health');
    console.log('NIST route enabled: /api/nist-controls');
});