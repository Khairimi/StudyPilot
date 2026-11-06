import 'package:flutter/material.dart';
import 'package:study_app/theme/app_theme.dart';
import 'package:study_app/models/subject.dart';

enum PriorityQuadrant { q1, q2, q3, q4 }
enum TimeRange { today, yesterday, last7Days, last30Days }

class AddSubjectDialog extends StatefulWidget {
  final Function(Subject) onSubjectAdded;

  const AddSubjectDialog({
    super.key,
    required this.onSubjectAdded,
  });

  @override
  State<AddSubjectDialog> createState() => _AddSubjectDialogState();
}

class _AddSubjectDialogState extends State<AddSubjectDialog> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  int _weightage = 20;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  PriorityQuadrant _selectedQuadrant = PriorityQuadrant.q1;
  Color _selectedColor = AppTheme.primaryColor;
  
  // Reminders
  bool _reminder48h = true;
  bool _reminder24h = true;
  bool _reminder3h = true;

  // Available colors for subject
  final List<Color> _availableColors = [
    AppTheme.primaryColor,
    const Color(0xFF22C07A), // Green
    const Color(0xFFF59E0B), // Amber
    const Color(0xFFE84F4F), // Red
    const Color(0xFF7B72F0), // Light purple
    const Color(0xFF3D34C0), // Dark purple
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _dueDate = date);
    }
  }

  void _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );
    if (time != null) {
      setState(() => _dueTime = time);
    }
  }

  void _saveSubject() {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a subject title')),
      );
      return;
    }

    final subject = Subject(
      id: DateTime.now().toString(),
      name: _titleController.text,
      colorValue: _selectedColor.value,
      weightage: _weightage,
      dueDate: _dueDate,
      dueTime: _dueTime,
      priority: _selectedQuadrant.toString().split('.').last,
      notes: _notesController.text,
    );

    widget.onSubjectAdded(subject);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey[200]!,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add Subject',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subject Title
                  _buildInputGroup(
                    label: 'Subject Title',
                    child: _buildInputField(
                      controller: _titleController,
                      hintText: 'e.g. Mathematics',
                      icon: Icons.edit,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Color Picker
                  _buildInputGroup(
                    label: 'Subject Color',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: _availableColors.map((color) {
                        final isSelected = color.value == _selectedColor.value;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColor = color),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.black : Colors.grey[300]!,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Weightage Slider
                  _buildInputGroup(
                    label: 'Weightage towards final grade',
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_weightage}%',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              Expanded(
                                child: Slider(
                                  value: _weightage.toDouble(),
                                  min: 0,
                                  max: 100,
                                  divisions: 100,
                                  onChanged: (value) {
                                    setState(() => _weightage = value.toInt());
                                  },
                                  activeColor: AppTheme.primaryColor,
                                  inactiveColor: Colors.grey[300],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '0%',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              Text(
                                'Typical: 10–30%',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                              Text(
                                '100%',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Due Date & Time
                  _buildInputGroup(
                    label: 'Due Date & Time',
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _selectDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              decoration: BoxDecoration(
                                color: _dueDate != null
                                    ? AppTheme.primaryColor.withAlpha(25)
                                    : Colors.grey[50],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _dueDate != null
                                      ? AppTheme.primaryColor
                                      : Colors.grey[200]!,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'DATE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _dueDate != null
                                        ? '${_dueDate!.day} ${_getMonthName(_dueDate!.month)} ${_dueDate!.year}'
                                        : 'Select date',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: _selectTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              decoration: BoxDecoration(
                                color: _dueTime != null
                                    ? AppTheme.primaryColor.withAlpha(25)
                                    : Colors.grey[50],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _dueTime != null
                                      ? AppTheme.primaryColor
                                      : Colors.grey[200]!,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TIME',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _dueTime != null
                                        ? _dueTime!.format(context)
                                        : 'Select time',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Priority Matrix
                  _buildInputGroup(
                    label: 'Priority — Urgency / Importance Matrix',
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        children: [
                          _buildMatrixCell(
                            'Q1 · Do First',
                            '🔴 Urgent + Important',
                            'Due soon, high weightage',
                            PriorityQuadrant.q1,
                            Colors.red[100]!,
                          ),
                          _buildMatrixCell(
                            'Q2 · Schedule',
                            '🟡 Not Urgent + Important',
                            'Plan ahead, still matters',
                            PriorityQuadrant.q2,
                            Colors.amber[100]!,
                          ),
                          _buildMatrixCell(
                            'Q3 · Delegate',
                            '🔵 Urgent + Less Important',
                            'Quick task, low impact',
                            PriorityQuadrant.q3,
                            Colors.blue[100]!,
                          ),
                          _buildMatrixCell(
                            'Q4 · Do Last',
                            '🟢 Not Urgent + Low',
                            'Backlog / optional',
                            PriorityQuadrant.q4,
                            Colors.green[100]!,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEDFB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '💡 Tip: App will auto-suggest based on due date + weightage — you can override here',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Smart Reminders
                  _buildInputGroup(
                    label: 'Smart Reminders',
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          _buildReminderRow('48 hours before', 'Early warning', _reminder48h,
                              (val) => setState(() => _reminder48h = val)),
                          Divider(height: 16, color: Colors.grey[200]),
                          _buildReminderRow('24 hours before', 'Day-before alert', _reminder24h,
                              (val) => setState(() => _reminder24h = val)),
                          Divider(height: 16, color: Colors.grey[200]),
                          _buildReminderRow('3 hours before', 'Final reminder', _reminder3h,
                              (val) => setState(() => _reminder3h = val)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Notes
                  _buildInputGroup(
                    label: 'Notes (optional)',
                    child: _buildTextArea(
                      controller: _notesController,
                      hintText: 'Instructions, resources, references...',
                      icon: Icons.note_alt_outlined,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveSubject,
                      icon: const Icon(Icons.check),
                      label: const Text('Save Subject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputGroup({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          border: InputBorder.none,
          icon: Icon(icon, size: 18, color: Colors.grey[500]),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildTextArea({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          border: InputBorder.none,
          icon: Icon(icon, size: 18, color: Colors.grey[500]),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        maxLines: 3,
      ),
    );
  }

  Widget _buildMatrixCell(
    String tag,
    String title,
    String desc,
    PriorityQuadrant quadrant,
    Color bgColor,
  ) {
    final isSelected = _selectedQuadrant == quadrant;
    return GestureDetector(
      onTap: () => setState(() => _selectedQuadrant = quadrant),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? bgColor : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? bgColor.withAlpha(150) : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
            Text(
              tag,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                letterSpacing: 0.3,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              desc,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderRow(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.primaryColor,
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}
