const db = require('../config/db');

const Task = {
  getAll: async (filter = {}) => {
    let query = 'SELECT * FROM tasks';
    const params = [];
    if (filter.completed !== undefined) {
      query += ' WHERE is_completed = ?';
      params.push(filter.completed === 'true' ? 1 : 0);
    }
    query += ' ORDER BY created_at DESC';
    const [rows] = await db.execute(query, params);
    return rows;
  },

  create: async ({ id, title, description, deadline }) => {
    await db.execute(
      'INSERT INTO tasks (id, title, description, deadline) VALUES (?, ?, ?, ?)',
      [id, title, description || null, deadline || null]
    );
    const [rows] = await db.execute('SELECT * FROM tasks WHERE id = ?', [id]);
    return rows[0];
  },

  update: async (id, { title, description, isCompleted, deadline }) => {
    await db.execute(
      `UPDATE tasks SET
        title = COALESCE(?, title),
        description = COALESCE(?, description),
        is_completed = COALESCE(?, is_completed),
        deadline = COALESCE(?, deadline)
       WHERE id = ?`,
      [title, description, isCompleted !== undefined ? (isCompleted ? 1 : 0) : null, deadline, id]
    );
    const [rows] = await db.execute('SELECT * FROM tasks WHERE id = ?', [id]);
    return rows[0];
  },

  delete: async (id) => {
    const [result] = await db.execute('DELETE FROM tasks WHERE id = ?', [id]);
    return result.affectedRows > 0;
  },
};

module.exports = Task;