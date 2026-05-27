const Task = require('../models/Task');

// Mapping dari snake_case DB ke camelCase Flutter
const formatTask = (row) => ({
  id: row.id,
  title: row.title,
  description: row.description,
  isCompleted: row.is_completed === 1,
  deadline: row.deadline,
  createdAt: row.created_at,
  updatedAt: row.updated_at,
});

exports.getAllTasks = async (req, res) => {
  try {
    const tasks = await Task.getAll(req.query);
    res.json({ success: true, data: tasks.map(formatTask) });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.createTask = async (req, res) => {
  try {
    const { id, title, description, deadline } = req.body;
    if (!title) return res.status(400).json({ success: false, message: 'Title wajib diisi' });
    const task = await Task.create({ id, title, description, deadline });
    res.status(201).json({ success: true, data: formatTask(task) });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.updateTask = async (req, res) => {
  try {
    const task = await Task.update(req.params.id, req.body);
    if (!task) return res.status(404).json({ success: false, message: 'Task tidak ditemukan' });
    res.json({ success: true, data: formatTask(task) });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.deleteTask = async (req, res) => {
  try {
    const deleted = await Task.delete(req.params.id);
    if (!deleted) return res.status(404).json({ success: false, message: 'Task tidak ditemukan' });
    res.json({ success: true, message: 'Task berhasil dihapus' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};