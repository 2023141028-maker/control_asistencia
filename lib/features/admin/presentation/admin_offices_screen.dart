import 'package:flutter/material.dart';

import '../../offices/domain/office.dart';
import '../domain/admin_repository.dart';

class AdminOfficesScreen extends StatefulWidget {
  const AdminOfficesScreen({required this.repository, super.key});

  final AdminRepository repository;

  @override
  State<AdminOfficesScreen> createState() => _AdminOfficesScreenState();
}

class _AdminOfficesScreenState extends State<AdminOfficesScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _saving = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openForm({Office? office}) async {
    final command = await showDialog<AdminOfficeSaveCommand>(
      context: context,
      builder: (context) => _OfficeFormDialog(office: office),
    );

    if (command == null || !mounted) {
      return;
    }

    setState(() => _saving = true);

    try {
      await widget.repository.saveOffice(command: command);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            office == null
                ? 'Sede registrada correctamente.'
                : 'Sede actualizada correctamente.',
          ),
        ),
      );
    } on AdminFailure catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la sede.')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Office>>(
      stream: widget.repository.watchOffices(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;

          return _OfficeMessage(
            icon: Icons.cloud_off,
            message: error is AdminFailure
                ? error.message
                : 'No se pudo cargar la lista de sedes.',
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final normalizedQuery = _query.trim().toLowerCase();

        final offices = snapshot.data!
            .where((office) {
              if (normalizedQuery.isEmpty) {
                return true;
              }

              return office.name.toLowerCase().contains(normalizedQuery) ||
                  office.id.toLowerCase().contains(normalizedQuery) ||
                  office.address.toLowerCase().contains(normalizedQuery);
            })
            .toList(growable: false);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() => _query = value);
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar sede',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpiar',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.clear),
                              ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _saving ? null : () => _openForm(),
                    icon: const Icon(Icons.add_business),
                    label: const Text('Nueva'),
                  ),
                ],
              ),
            ),
            if (_saving) const LinearProgressIndicator(),
            Expanded(
              child: offices.isEmpty
                  ? const _OfficeMessage(
                      icon: Icons.business_outlined,
                      message: 'No se encontraron sedes.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: offices.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final office = offices[index];

                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            leading: CircleAvatar(
                              child: Icon(
                                office.active
                                    ? Icons.business
                                    : Icons.domain_disabled,
                              ),
                            ),
                            title: Text(
                              office.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(office.address),
                                  Text('ID: ${office.id}'),
                                  Text(
                                    'Radio: '
                                    '${office.radiusMeters.toStringAsFixed(0)} m'
                                    ' · Precisión: '
                                    '${office.maxAccuracyMeters.toStringAsFixed(0)} m',
                                  ),
                                  Text(
                                    office.active ? 'Activa' : 'Inactiva',
                                    style: TextStyle(
                                      color: office.active
                                          ? Colors.green.shade700
                                          : Theme.of(context).colorScheme.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: IconButton(
                              tooltip: 'Editar sede',
                              onPressed: _saving
                                  ? null
                                  : () => _openForm(office: office),
                              icon: const Icon(Icons.edit_location_alt),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _OfficeFormDialog extends StatefulWidget {
  const _OfficeFormDialog({this.office});

  final Office? office;

  @override
  State<_OfficeFormDialog> createState() => _OfficeFormDialogState();
}

class _OfficeFormDialogState extends State<_OfficeFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _idController;
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _radiusController;
  late final TextEditingController _accuracyController;

  late bool _active;

  bool get _isNew => widget.office == null;

  @override
  void initState() {
    super.initState();

    final office = widget.office;

    _idController = TextEditingController(text: office?.id ?? '');
    _nameController = TextEditingController(text: office?.name ?? '');
    _addressController = TextEditingController(text: office?.address ?? '');
    _latitudeController = TextEditingController(
      text: office?.latitude.toString() ?? '',
    );
    _longitudeController = TextEditingController(
      text: office?.longitude.toString() ?? '',
    );
    _radiusController = TextEditingController(
      text: office?.radiusMeters.toStringAsFixed(0) ?? '100',
    );
    _accuracyController = TextEditingController(
      text: office?.maxAccuracyMeters.toStringAsFixed(0) ?? '30',
    );
    _active = office?.active ?? true;
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _radiusController.dispose();
    _accuracyController.dispose();
    super.dispose();
  }

  double? _numberFrom(TextEditingController controller) {
    return double.tryParse(controller.text.trim().replaceAll(',', '.'));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      AdminOfficeSaveCommand(
        id: _idController.text.trim(),
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        latitude: _numberFrom(_latitudeController)!,
        longitude: _numberFrom(_longitudeController)!,
        radiusMeters: _numberFrom(_radiusController)!,
        maxAccuracyMeters: _numberFrom(_accuracyController)!,
        active: _active,
        isNew: _isNew,
      ),
    );
  }

  String? _requiredText(
    String? value, {
    required int minimum,
    required int maximum,
  }) {
    final normalized = value?.trim() ?? '';

    if (normalized.length < minimum || normalized.length > maximum) {
      return 'Usa entre $minimum y $maximum caracteres.';
    }

    return null;
  }

  String? _numberValidator(
    String? value, {
    required double minimum,
    required double maximum,
  }) {
    final number = double.tryParse((value ?? '').trim().replaceAll(',', '.'));

    if (number == null || number < minimum || number > maximum) {
      return 'Ingresa un valor entre $minimum y $maximum.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isNew ? 'Nueva sede' : 'Editar sede'),
      content: SizedBox(
        width: 540,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _idController,
                  readOnly: !_isNew,
                  textCapitalization: TextCapitalization.none,
                  decoration: const InputDecoration(
                    labelText: 'Identificador',
                    hintText: 'ejemplo: unh-pampas',
                    prefixIcon: Icon(Icons.key),
                  ),
                  validator: (value) {
                    final id = value?.trim() ?? '';

                    if (!RegExp(r'^[a-z0-9-]{3,50}$').hasMatch(id)) {
                      return 'Usa minúsculas, números y guiones.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  validator: (value) =>
                      _requiredText(value, minimum: 3, maximum: 100),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Dirección',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                  validator: (value) =>
                      _requiredText(value, minimum: 5, maximum: 200),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latitudeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Latitud'),
                        validator: (value) =>
                            _numberValidator(value, minimum: -90, maximum: 90),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _longitudeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Longitud',
                        ),
                        validator: (value) => _numberValidator(
                          value,
                          minimum: -180,
                          maximum: 180,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _radiusController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Radio (m)',
                        ),
                        validator: (value) =>
                            _numberValidator(value, minimum: 20, maximum: 500),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _accuracyController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Precisión (m)',
                        ),
                        validator: (value) =>
                            _numberValidator(value, minimum: 5, maximum: 100),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sede activa'),
                  subtitle: const Text(
                    'Las sedes inactivas no permiten registrar asistencia.',
                  ),
                  value: _active,
                  onChanged: (value) {
                    setState(() => _active = value);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save),
          label: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _OfficeMessage extends StatelessWidget {
  const _OfficeMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
