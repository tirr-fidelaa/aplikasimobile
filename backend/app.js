const express = require('express');
const cors = require('cors');
const app = express();

app.use(cors());   // izinkan request dari Flutter/emulator
app.use(express.json());

app.use('/api/tasks', require('./routes/tasks'));

// 404 handler
app.use((req, res) => res.status(404).json({ success: false, message: 'Endpoint tidak ditemukan' }));

module.exports = app;