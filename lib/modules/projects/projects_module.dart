import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Módulo autónomo de Proyectos para EduNova.
///
/// Entrada pública: [ProjectsScreen]. No requiere cambios en otras pantallas
/// fuera del caso de navegación que se describe en README.md.
class Project {
  final String id;
  final String title;
  final String subject;
  final DateTime dueDate;
  final List<String> teacherBrief;
  final List<ProjectStep> steps;
  final List<ProjectResource> resources;
  final int colorValue;
  final DateTime createdAt;
  final DateTime? deliveredAt;

  const Project({
    required this.id,
    required this.title,
    required this.subject,
    required this.dueDate,
    required this.teacherBrief,
    required this.steps,
    required this.resources,
    required this.colorValue,
    required this.createdAt,
    this.deliveredAt,
  });

  bool get isDelivered => deliveredAt != null;
  int get completedSteps => steps.where((step) => step.completed).length;
  double get progress => steps.isEmpty ? 0 : completedSteps / steps.length;

  Project copyWith({
    List<ProjectStep>? steps,
    List<ProjectResource>? resources,
    DateTime? deliveredAt,
    bool clearDeliveredAt = false,
  }) {
    return Project(
      id: id,
      title: title,
      subject: subject,
      dueDate: dueDate,
      teacherBrief: teacherBrief,
      steps: steps ?? this.steps,
      resources: resources ?? this.resources,
      colorValue: colorValue,
      createdAt: createdAt,
      deliveredAt: clearDeliveredAt ? null : (deliveredAt ?? this.deliveredAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subject': subject,
        'dueDate': dueDate.toIso8601String(),
        'teacherBrief': teacherBrief,
        'steps': steps.map((step) => step.toJson()).toList(),
        'resources': resources.map((resource) => resource.toJson()).toList(),
        'colorValue': colorValue,
        'createdAt': createdAt.toIso8601String(),
        'deliveredAt': deliveredAt?.toIso8601String(),
      };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        title: json['title'] as String,
        subject: json['subject'] as String,
        dueDate: DateTime.parse(json['dueDate'] as String),
        teacherBrief: List<String>.from(json['teacherBrief'] as List),
        steps: (json['steps'] as List)
            .map((step) => ProjectStep.fromJson(Map<String, dynamic>.from(step)))
            .toList(),
        resources: (json['resources'] as List)
            .map((resource) => ProjectResource.fromJson(Map<String, dynamic>.from(resource)))
            .toList(),
        colorValue: json['colorValue'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
        deliveredAt: json['deliveredAt'] == null
            ? null
            : DateTime.parse(json['deliveredAt'] as String),
      );
}

class ProjectStep {
  final String id;
  final String title;
  final bool completed;

  const ProjectStep({required this.id, required this.title, this.completed = false});

  ProjectStep copyWith({bool? completed}) => ProjectStep(
        id: id,
        title: title,
        completed: completed ?? this.completed,
      );

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'completed': completed};

  factory ProjectStep.fromJson(Map<String, dynamic> json) => ProjectStep(
        id: json['id'] as String,
        title: json['title'] as String,
        completed: json['completed'] as bool? ?? false,
      );
}

class ProjectResource {
  final String id;
  final String name;
  final String value;
  final bool isLink;

  const ProjectResource({
    required this.id,
    required this.name,
    required this.value,
    required this.isLink,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'value': value,
        'isLink': isLink,
      };

  factory ProjectResource.fromJson(Map<String, dynamic> json) => ProjectResource(
        id: json['id'] as String,
        name: json['name'] as String,
        value: json['value'] as String,
        isLink: json['isLink'] as bool? ?? false,
      );
}

class ProjectsRepository {
  static const _storagePrefix = 'edunova_projects_module_v1';

  Future<String> _storageKey(SharedPreferences preferences) async {
    final correo = preferences.getString('edunova_usuario_actual');
    if (correo == null || correo.isEmpty) return _storagePrefix;
    return '${_storagePrefix}_${base64UrlEncode(utf8.encode(correo.toLowerCase()))}';
  }

  Future<List<Project>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(await _storageKey(preferences));
    if (raw == null || raw.isEmpty) return _examples();
    try {
      return (jsonDecode(raw) as List)
          .map((item) => Project.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return _examples();
    }
  }

  Future<void> save(List<Project> projects) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      await _storageKey(preferences),
      jsonEncode(projects.map((project) => project.toJson()).toList()),
    );
  }

  List<Project> _examples() {
    final now = DateTime.now();
    return [
      Project(
        id: 'solar-system',
        title: 'Maqueta del Sistema Solar',
        subject: 'Ciencias Naturales',
        dueDate: now.add(const Duration(days: 4)),
        teacherBrief: const [
          'Representar los planetas en orden desde el Sol.',
          'Incluir una ficha con datos de cada planeta.',
          'Presentar el trabajo y explicar dos datos interesantes.',
        ],
        steps: const [
          ProjectStep(id: 'solar-1', title: 'Investigar información de los planetas'),
          ProjectStep(id: 'solar-2', title: 'Hacer un borrador de la maqueta'),
          ProjectStep(id: 'solar-3', title: 'Diseñar y armar la entrega final'),
          ProjectStep(id: 'solar-4', title: 'Practicar la explicación'),
        ],
        resources: const [],
        colorValue: 0xFF4F46E5,
        createdAt: now,
      ),
      Project(
        id: 'history-essay',
        title: 'Ensayo de Historia',
        subject: 'Historia',
        dueDate: now.add(const Duration(days: 9)),
        teacherBrief: const [
          'Defender una idea principal con fuentes confiables.',
          'Usar introducción, desarrollo y conclusión.',
          'Revisar ortografía y agregar bibliografía.',
        ],
        steps: const [
          ProjectStep(id: 'history-1', title: 'Elegir la tesis del ensayo'),
          ProjectStep(id: 'history-2', title: 'Buscar y organizar las fuentes'),
          ProjectStep(id: 'history-3', title: 'Escribir el borrador'),
        ],
        resources: const [],
        colorValue: 0xFF0F766E,
        createdAt: now,
      ),
    ];
  }
}

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> with SingleTickerProviderStateMixin {
  final _repository = ProjectsRepository();
  List<Project> _projects = [];
  bool _loading = true;
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    final projects = await _repository.load();
    if (!mounted) return;
    setState(() {
      _projects = projects;
      _loading = false;
    });
  }

  Future<void> _save() => _repository.save(_projects);

  Future<void> _createProject() async {
    final project = await Navigator.push<Project>(
      context,
      MaterialPageRoute(builder: (_) => const ProjectCreateScreen()),
    );
    if (project == null) return;
    setState(() => _projects.insert(0, project));
    await _save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proyecto creado. ¡Ya tienes un buen primer paso!')),
      );
    }
  }

  Future<void> _openProject(Project project) async {
    final updated = await Navigator.push<Project>(
      context,
      MaterialPageRoute(builder: (_) => ProjectDetailScreen(project: project)),
    );
    if (updated == null) return;
    setState(() {
      final index = _projects.indexWhere((item) => item.id == updated.id);
      if (index >= 0) _projects[index] = updated;
    });
    await _save();
    if (updated.isDelivered && mounted) _celebrate(updated);
  }

  void _celebrate(Project project) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 58)),
            const SizedBox(height: 8),
            const Text('¡Proyecto entregado!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Completaste “${project.title}”. Tu esfuerzo cuenta muchísimo.', textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('¡Genial!')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis proyectos'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'En curso'), Tab(text: 'Entregados')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createProject,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo proyecto'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _ProjectList(projects: _projects.where((project) => !project.isDelivered).toList(), onTap: _openProject),
                _ProjectList(projects: _projects.where((project) => project.isDelivered).toList(), onTap: _openProject, delivered: true),
              ],
            ),
    );
  }
}

class _ProjectList extends StatelessWidget {
  final List<Project> projects;
  final ValueChanged<Project> onTap;
  final bool delivered;

  const _ProjectList({required this.projects, required this.onTap, this.delivered = false});

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(delivered ? Icons.emoji_events_outlined : Icons.lightbulb_outline, size: 70, color: Colors.indigo.shade300),
              const SizedBox(height: 16),
              Text(delivered ? 'Aquí aparecerán tus proyectos terminados.' : 'No hay proyectos en curso todavía.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: projects.length,
      itemBuilder: (context, index) => _ProjectCard(project: projects[index], onTap: () => onTap(projects[index])),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;

  const _ProjectCard({required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Color(project.colorValue);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 6, height: 74, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(project.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Text(project.subject, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(project.isDelivered ? 'Entregado' : _remaining(project.dueDate), style: TextStyle(color: project.isDelivered ? Colors.green : Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade500),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(value: project.progress, minHeight: 9, color: color, backgroundColor: color.withAlpha(35)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${(project.progress * 100).round()}%', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                ],
              ),
              const SizedBox(height: 7),
              Text('${project.completedSteps} de ${project.steps.length} pasos completados', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }
}

class ProjectDetailScreen extends StatefulWidget {
  final Project project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late Project _project;
  Timer? _timer;
  int _secondsLeft = 25 * 60;
  bool _timerRunning = false;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleStep(int index, bool value) {
    final steps = [..._project.steps];
    steps[index] = steps[index].copyWith(completed: value);
    final completed = steps.every((step) => step.completed);
    setState(() {
      _project = _project.copyWith(
        steps: steps,
        deliveredAt: completed ? DateTime.now() : null,
        clearDeliveredAt: !completed,
      );
    });
    if (value) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Buen avance! Un paso menos por completar.')));
    }
  }

  void _startPomodoro() {
    if (_timerRunning) {
      _timer?.cancel();
      setState(() => _timerRunning = false);
      return;
    }
    setState(() => _timerRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _secondsLeft = 25 * 60;
          _timerRunning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Excelente sesión! Tómate un descanso, vas muy bien.')));
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _addLink() async {
    final name = TextEditingController();
    final url = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar enlace'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre (ej. Canva)')),
          const SizedBox(height: 10),
          TextField(controller: url, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'URL', hintText: 'https://...')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, name.text.trim().isNotEmpty && url.text.trim().isNotEmpty), child: const Text('Guardar')),
        ],
      ),
    );
    if (added != true) return;
    setState(() {
      _project = _project.copyWith(resources: [
        ..._project.resources,
        ProjectResource(id: DateTime.now().microsecondsSinceEpoch.toString(), name: name.text.trim(), value: url.text.trim(), isLink: true),
      ]);
    });
  }

  Future<void> _addFile() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result == null || result.files.single.name.isEmpty) return;
    final file = result.files.single;
    setState(() {
      _project = _project.copyWith(resources: [
        ..._project.resources,
        ProjectResource(id: DateTime.now().microsecondsSinceEpoch.toString(), name: file.name, value: file.path ?? file.name, isLink: false),
      ]);
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recurso agregado al proyecto.')));
  }

  String _time() => '${(_secondsLeft ~/ 60).toString().padLeft(2, '0')}:${(_secondsLeft % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final color = Color(_project.colorValue);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del proyecto'),
        actions: [
          IconButton(onPressed: _startPomodoro, tooltip: 'Modo de enfoque', icon: Icon(_timerRunning ? Icons.pause_circle : Icons.timer_outlined)),
          IconButton(onPressed: () => Navigator.pop(context, _project), icon: const Icon(Icons.check)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: color.withAlpha(22), borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withAlpha(70))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_project.title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [Icon(Icons.book_outlined, size: 18, color: color), const SizedBox(width: 6), Text(_project.subject, style: TextStyle(color: color, fontWeight: FontWeight.bold)), const Spacer(), Icon(Icons.event_outlined, size: 18, color: color), const SizedBox(width: 5), Text(_date(_project.dueDate))]),
              const SizedBox(height: 16),
              Text(_project.isDelivered ? 'Proyecto entregado' : _remaining(_project.dueDate), style: TextStyle(color: _project.isDelivered ? Colors.green : color, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(height: 18),
          if (_timerRunning || _secondsLeft != 25 * 60) Card(color: Colors.indigo.shade50, child: ListTile(leading: const Icon(Icons.timer, color: Colors.indigo), title: const Text('Modo de enfoque'), subtitle: Text(_timerRunning ? 'Concéntrate en este proyecto · ${_time()}' : 'Sesión pausada · ${_time()}'), trailing: FilledButton(onPressed: _startPomodoro, child: Text(_timerRunning ? 'Pausar' : 'Continuar')))),
          _sectionTitle('Lo que pide el profe', Icons.assignment_outlined),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _project.teacherBrief.map((item) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.check_circle_outline, size: 19, color: color), const SizedBox(width: 9), Expanded(child: Text(item))]))).toList()))),
          _sectionTitle('Pasos del proyecto', Icons.checklist_rounded),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < _project.steps.length; i++)
                  CheckboxListTile(
                    value: _project.steps[i].completed,
                    onChanged: (value) => _toggleStep(i, value ?? false),
                    title: Text(
                      _project.steps[i].title,
                      style: TextStyle(
                        decoration: _project.steps[i].completed
                            ? TextDecoration.lineThrough
                            : null,
                        color: _project.steps[i].completed ? Colors.grey : null,
                      ),
                    ),
                    secondary: CircleAvatar(
                      radius: 14,
                      backgroundColor: color.withAlpha(25),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(color: color, fontWeight: FontWeight.bold),
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.trailing,
                  ),
              ],
            ),
          ),
          _sectionTitle('Cajón de recursos', Icons.inventory_2_outlined),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  if (_project.resources.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Guarda aquí tus enlaces y archivos para tenerlos a mano.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ..._project.resources.map(
                      (resource) => ListTile(
                        leading: Icon(
                          resource.isLink ? Icons.link : Icons.attach_file,
                          color: color,
                        ),
                        title: Text(resource.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: resource.isLink
                            ? Text(resource.value, maxLines: 1, overflow: TextOverflow.ellipsis)
                            : const Text('Archivo adjunto'),
                        onTap: resource.isLink ? () => _openLink(resource.value) : null,
                      ),
                    ),
                  const Divider(height: 1),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: _addLink,
                          icon: const Icon(Icons.link),
                          label: const Text('Enlace'),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: _addFile,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Archivo'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) => Padding(padding: const EdgeInsets.only(top: 22, bottom: 9), child: Row(children: [Icon(icon, color: Colors.indigo), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold))]));

  Future<void> _openLink(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir el enlace.')));
    }
  }
}

class ProjectCreateScreen extends StatefulWidget {
  const ProjectCreateScreen({super.key});

  @override
  State<ProjectCreateScreen> createState() => _ProjectCreateScreenState();
}

class _ProjectCreateScreenState extends State<ProjectCreateScreen> {
  final _title = TextEditingController();
  final _subject = TextEditingController();
  final _brief = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  int _colorValue = 0xFF4F46E5;

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    _brief.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(context: context, initialDate: _dueDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)));
    if (selected != null) setState(() => _dueDate = selected);
  }

  void _create() {
    if (_title.text.trim().isEmpty || _subject.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa el nombre y la materia para comenzar.')));
      return;
    }
    final brief = _brief.text.trim().isEmpty ? <String>[] : _brief.text.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
    final title = _title.text.trim();
    final steps = _suggestedSteps(title);
    Navigator.pop(context, Project(id: DateTime.now().microsecondsSinceEpoch.toString(), title: title, subject: _subject.text.trim(), dueDate: _dueDate, teacherBrief: brief, steps: steps, resources: const [], colorValue: _colorValue, createdAt: DateTime.now()));
  }

  List<ProjectStep> _suggestedSteps(String title) => [
        ProjectStep(id: '${title}1', title: 'Investigar información y reunir ideas'),
        ProjectStep(id: '${title}2', title: 'Hacer un borrador o esquema'),
        ProjectStep(id: '${title}3', title: 'Preparar la entrega final'),
        ProjectStep(id: '${title}4', title: 'Revisar y practicar antes de entregar'),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear proyecto')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Vamos a organizarlo juntos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 7),
        const Text('Responde lo básico y te propondremos pasos para empezar sin complicarte.'),
        const SizedBox(height: 22),
        TextField(controller: _title, autofocus: true, decoration: const InputDecoration(labelText: '¿De qué es el proyecto?', hintText: 'Ej. Exposición de biología', border: OutlineInputBorder())),
        const SizedBox(height: 14),
        TextField(controller: _subject, decoration: const InputDecoration(labelText: '¿Para qué materia?', hintText: 'Ej. Ciencias Naturales', border: OutlineInputBorder())),
        const SizedBox(height: 14),
        OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_today), label: Text('Fecha de entrega: ${_date(_dueDate)}')),
        const SizedBox(height: 14),
        TextField(controller: _brief, maxLines: 4, decoration: const InputDecoration(labelText: '¿Qué pide el profe?', hintText: 'Escribe un requisito por línea (opcional)', border: OutlineInputBorder())),
        const SizedBox(height: 22),
        const Text('Color del proyecto', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(spacing: 10, children: [0xFF4F46E5, 0xFF0F766E, 0xFFE07A1F, 0xFFBE185D, 0xFF7C3AED].map((value) => GestureDetector(onTap: () => setState(() => _colorValue = value), child: CircleAvatar(radius: 18, backgroundColor: Color(value), child: _colorValue == value ? const Icon(Icons.check, color: Colors.white) : null))).toList()),
        const SizedBox(height: 30),
        FilledButton.icon(onPressed: _create, icon: const Icon(Icons.auto_awesome), label: const Padding(padding: EdgeInsets.symmetric(vertical: 13), child: Text('Crear con pasos sugeridos'))),
      ]),
    );
  }
}

String _date(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _remaining(DateTime dueDate) {
  final days = dueDate.difference(DateTime.now()).inDays;
  if (days < 0) return 'Fecha vencida';
  if (days == 0) return 'Se entrega hoy';
  if (days == 1) return 'Falta 1 día';
  return 'Faltan $days días';
}
