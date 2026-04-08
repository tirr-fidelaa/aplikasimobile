import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/task_services.dart';

class AddTaskPage extends StatefulWidget {
  final TaskModel? existingTask;
  final Function(TaskModel) onSave;

  const AddTaskPage({Key? key, this.existingTask, required this.onSave}) : super(key: key);

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _subtaskController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _slideAnimation;

  TaskStatus _status = TaskStatus.open;
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _dueDate;
  int? _reminderHour;
  int? _reminderMinute;
  bool _hasReminder = false;
  RecurringType _recurringType = RecurringType.none;
  List<SubTask> _subtasks = [];
  String? _projectName;

  bool get _isEditing => widget.existingTask != null;

  String get _reminderText {
    if (_reminderHour == null) return '';
    final h = _reminderHour.toString().padLeft(2, '0');
    final m = (_reminderMinute ?? 0).toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();

    if (widget.existingTask != null) {
      final t = widget.existingTask!;
      _titleController.text = t.title;
      _descController.text = t.description;
      _status = t.status;
      _priority = t.priority;
      _dueDate = t.dueDate;
      if (t.reminderTime != null) {
        _reminderHour = t.reminderTime!.hour;
        _reminderMinute = t.reminderTime!.minute;
      }
      _hasReminder = t.hasReminder;
      _recurringType = t.recurringType;
      _subtasks = List.from(t.subtasks.map((s) => SubTask(id: s.id, title: s.title, isCompleted: s.isCompleted)));
      _projectName = t.projectName;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  void _save() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a task name')));
      return;
    }
    final ModelTimeOfDay? reminder = (_reminderHour != null)
        ? ModelTimeOfDay(hour: _reminderHour!, minute: _reminderMinute ?? 0)
        : null;

    final task = TaskModel(
      id: _isEditing ? widget.existingTask!.id : TaskServices.generateId(),
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      status: _status,
      priority: _priority,
      dueDate: _dueDate,
      reminderTime: reminder,
      hasReminder: _hasReminder,
      subtasks: _subtasks,
      recurringType: _recurringType,
      createdAt: _isEditing ? widget.existingTask!.createdAt : DateTime.now(),
      projectName: _projectName,
    );
    widget.onSave(task);
    Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF4CAF8D), onPrimary: Colors.white)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour ?? 9, minute: _reminderMinute ?? 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF4CAF8D))),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() { _reminderHour = picked.hour; _reminderMinute = picked.minute; _hasReminder = true; });
    }
  }

  void _addSubtask() {
    if (_subtaskController.text.trim().isEmpty) return;
    setState(() {
      _subtasks.add(SubTask(id: DateTime.now().millisecondsSinceEpoch.toString(), title: _subtaskController.text.trim()));
      _subtaskController.clear();
    });
  }

  void _toggleSubtask(int index) => setState(() => _subtasks[index].isCompleted = !_subtasks[index].isCompleted);
  void _removeSubtask(int index) => setState(() => _subtasks.removeAt(index));

  Color get _priorityColor {
    switch (_priority) {
      case TaskPriority.low: return const Color(0xFF64B5F6);
      case TaskPriority.medium: return const Color(0xFFFFB74D);
      case TaskPriority.high: return const Color(0xFFEF5350);
      case TaskPriority.urgent: return const Color(0xFF9C27B0);
    }
  }

  String get _priorityLabel {
    switch (_priority) {
      case TaskPriority.low: return 'Low';
      case TaskPriority.medium: return 'Medium';
      case TaskPriority.high: return 'High';
      case TaskPriority.urgent: return 'Urgent';
    }
  }

  String get _recurringLabel {
    switch (_recurringType) {
      case RecurringType.none: return 'No Repeat';
      case RecurringType.daily: return 'Daily';
      case RecurringType.weekly: return 'Weekly';
      case RecurringType.monthly: return 'Monthly';
      case RecurringType.yearly: return 'Yearly';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _slideAnimation.value * 60),
        child: Opacity(opacity: 1 - _slideAnimation.value * 0.5, child: child),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(_isEditing ? 'Edit Task' : 'New Task',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 16)),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: "Task name or type '/' for commands",
                  hintStyle: TextStyle(color: Colors.black38, fontSize: 16, fontWeight: FontWeight.normal),
                  border: InputBorder.none,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _showProjectPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          const Icon(Icons.search, size: 16, color: Colors.black38),
                          const SizedBox(width: 8),
                          Text(_projectName ?? 'Select List',
                            style: TextStyle(color: _projectName != null ? Colors.black : Colors.black38, fontSize: 14)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('For', style: TextStyle(color: Colors.black54, fontSize: 13)),
                  const SizedBox(width: 12),
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black12)),
                    child: const Icon(Icons.add, size: 18, color: Colors.black38),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 100),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(10)),
                child: TextField(
                  controller: _descController,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: "Description or type '/' for commands",
                    hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
                    border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _actionChip(Icons.add, 'Add Subtask', _showSubtaskSheet),
                  const SizedBox(width: 16),
                  _actionChip(Icons.add, 'Add Checklist', _showSubtaskSheet),
                ],
              ),
              if (_subtasks.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    children: _subtasks.asMap().entries.map((entry) {
                      final i = entry.key;
                      final s = entry.value;
                      return ListTile(
                        dense: true,
                        leading: GestureDetector(
                          onTap: () => _toggleSubtask(i),
                          child: Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: s.isCompleted ? const Color(0xFF4CAF8D) : Colors.transparent,
                              border: Border.all(color: s.isCompleted ? const Color(0xFF4CAF8D) : Colors.black26),
                            ),
                            child: s.isCompleted ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                          ),
                        ),
                        title: Text(s.title, style: TextStyle(
                          fontSize: 14,
                          decoration: s.isCompleted ? TextDecoration.lineThrough : null,
                          color: s.isCompleted ? Colors.black38 : Colors.black,
                        )),
                        trailing: GestureDetector(
                          onTap: () => _removeSubtask(i),
                          child: const Icon(Icons.close, size: 16, color: Colors.black38),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(color: const Color(0xFFEDF7F3), borderRadius: BorderRadius.circular(10)),
                child: Column(
                  children: [
                    const Text('Drag & Drop files to attach or Browse', style: TextStyle(color: Colors.black45, fontSize: 13)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFB8D8C7)), borderRadius: BorderRadius.circular(8)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('Browse', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        SizedBox(width: 6),
                        Icon(Icons.attach_file, size: 14),
                      ]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Properties', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black54)),
              const SizedBox(height: 12),
              _propertyRow(icon: Icons.circle_outlined, label: 'Status', child: _statusDropdown()),
              const Divider(height: 1, color: Colors.black12),
              _propertyRow(
                icon: Icons.flag_outlined, label: 'Priority',
                child: GestureDetector(
                  onTap: _showPriorityPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: _priorityColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.circle, size: 8, color: _priorityColor),
                      const SizedBox(width: 5),
                      Text(_priorityLabel, style: TextStyle(color: _priorityColor, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
              const Divider(height: 1, color: Colors.black12),
              _propertyRow(
                icon: Icons.calendar_today_outlined, label: 'Due Date',
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Text(
                    _dueDate != null ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}' : 'Set date',
                    style: TextStyle(color: _dueDate != null ? Colors.black : Colors.black38, fontSize: 13),
                  ),
                ),
              ),
              const Divider(height: 1, color: Colors.black12),
              _propertyRow(
                icon: Icons.notifications_none, label: 'Reminder',
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Switch(
                    value: _hasReminder,
                    onChanged: (v) { if (v) { _pickReminderTime(); } else { setState(() => _hasReminder = false); } },
                    activeColor: const Color(0xFF4CAF8D),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  if (_hasReminder && _reminderHour != null)
                    GestureDetector(
                      onTap: _pickReminderTime,
                      child: Text(_reminderText, style: const TextStyle(fontSize: 13, color: Color(0xFF4CAF8D))),
                    ),
                ]),
              ),
              const Divider(height: 1, color: Colors.black12),
              _propertyRow(
                icon: Icons.repeat, label: 'Repeat',
                child: GestureDetector(
                  onTap: _showRecurringPicker,
                  child: Text(
                    _recurringLabel,
                    style: TextStyle(
                      color: _recurringType != RecurringType.none ? const Color(0xFF4CAF8D) : Colors.black38,
                      fontSize: 13,
                      fontWeight: _recurringType != RecurringType.none ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(
              children: [
                _bottomIcon(Icons.person_outline, () {}),
                const SizedBox(width: 8),
                _bottomIcon(Icons.calendar_month_outlined, _pickDate),
                const SizedBox(width: 8),
                _bottomIcon(Icons.bolt_outlined, () {}),
                const SizedBox(width: 8),
                _bottomIcon(Icons.checklist, _showSubtaskSheet),
                const Spacer(),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D7A5F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: Text(_isEditing ? 'Save Task' : 'Create Task',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionChip(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 22, height: 22,
          decoration: const BoxDecoration(color: Color(0xFF4CAF8D), shape: BoxShape.circle),
          child: Icon(icon, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
      ]),
    );
  }

  Widget _propertyRow({required IconData icon, required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.black45),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: Colors.black54))),
        child,
      ]),
    );
  }

  Widget _statusDropdown() {
    return DropdownButton<TaskStatus>(
      value: _status, isDense: true, underline: const SizedBox(),
      items: TaskStatus.values.map((s) {
        final data = {TaskStatus.open: ['grey', 'Open'], TaskStatus.inProgress: ['orange', 'In Progress'], TaskStatus.done: ['green', 'Done']};
        final colors = {TaskStatus.open: Colors.grey, TaskStatus.inProgress: Colors.orange, TaskStatus.done: const Color(0xFF4CAF8D)};
        return DropdownMenuItem(
          value: s,
          child: Row(children: [
            Icon(Icons.circle, size: 8, color: colors[s]),
            const SizedBox(width: 6),
            Text(data[s]![1], style: const TextStyle(fontSize: 13)),
          ]),
        );
      }).toList(),
      onChanged: (v) => setState(() => _status = v!),
    );
  }

  Widget _bottomIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black12)),
        child: Icon(icon, size: 18, color: Colors.black45),
      ),
    );
  }

  void _showProjectPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        final projects = ['Personal', 'Work', 'Shopping', 'Health', 'Finance'];
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Select Project', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 12),
            ...projects.map((p) => ListTile(
              title: Text(p), leading: const Icon(Icons.folder_outlined),
              onTap: () { setState(() => _projectName = p); Navigator.pop(context); },
            )),
          ],
        );
      },
    );
  }

  void _showPriorityPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        final info = {
          TaskPriority.low: [const Color(0xFF64B5F6), 'Low'],
          TaskPriority.medium: [const Color(0xFFFFB74D), 'Medium'],
          TaskPriority.high: [const Color(0xFFEF5350), 'High'],
          TaskPriority.urgent: [const Color(0xFF9C27B0), 'Urgent'],
        };
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(16), child: Text('Select Priority', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
            ...TaskPriority.values.map((p) => ListTile(
              leading: Icon(Icons.circle, color: info[p]![0] as Color, size: 14),
              title: Text(info[p]![1] as String),
              trailing: _priority == p ? const Icon(Icons.check, color: Color(0xFF4CAF8D)) : null,
              onTap: () { setState(() => _priority = p); Navigator.pop(context); },
            )),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  void _showRecurringPicker() {
    const labels = ['No Repeat', 'Daily', 'Weekly', 'Monthly', 'Yearly'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Repeat Task', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
          ...RecurringType.values.map((r) => ListTile(
            leading: Icon(Icons.repeat, color: r != RecurringType.none ? const Color(0xFF4CAF8D) : Colors.black38),
            title: Text(labels[r.index]),
            trailing: _recurringType == r ? const Icon(Icons.check, color: Color(0xFF4CAF8D)) : null,
            onTap: () { setState(() => _recurringType = r); Navigator.pop(context); },
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showSubtaskSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Subtask', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subtaskController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Subtask name...',
                      filled: true, fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () { _addSubtask(); Navigator.pop(context); },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF8D),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

typedef ModelTimeOfDay = TimeOfDay;