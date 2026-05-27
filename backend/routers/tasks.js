const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/taskController');

router.get('/',       ctrl.getAllTasks);
router.post('/',      ctrl.createTask);
router.put('/:id',    ctrl.updateTask);
router.delete('/:id', ctrl.deleteTask);

module.exports = router;