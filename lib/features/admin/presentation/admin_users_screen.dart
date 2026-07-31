import 'package:flutter/material.dart';

import '../../offices/domain/office.dart';
import '../../users/domain/user_profile.dart';
import '../domain/admin_repository.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({
    required this.currentAdmin,
    required this.repository,
    super.key,
  });

  final UserProfile currentAdmin;
  final AdminRepository repository;

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _saving = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createUser(List<Office> offices) async {
    final result = await showDialog<_UserFormResult>(
      context: context,
      builder: (context) => _UserFormDialog(
        title: 'Nuevo trabajador',
        offices: offices,
        isCreating: true,
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    await _runOperation(() {
      return widget.repository.createUser(
        command: AdminUserCreateCommand(
          email: result.email!,
          temporaryPassword: result.password!,
          fullName: result.fullName,
          employeeCode: result.employeeCode,
          role: result.role,
          status: result.status,
          officeId: result.officeId,
        ),
      );
    }, successMessage: 'Trabajador registrado correctamente.');
  }

  Future<void> _editUser(UserProfile user, List<Office> offices) async {
    final isCurrentAdmin = user.uid == widget.currentAdmin.uid;

    final result = await showDialog<_UserFormResult>(
      context: context,
      builder: (context) => _UserFormDialog(
        title: 'Editar perfil',
        offices: offices,
        user: user,
        lockPrivileges: isCurrentAdmin,
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    await _runOperation(() {
      return widget.repository.updateUser(
        command: AdminUserUpdateCommand(
          uid: user.uid,
          fullName: result.fullName,
          employeeCode: result.employeeCode,
          role: result.role,
          status: result.status,
          officeId: result.officeId,
        ),
      );
    }, successMessage: 'Perfil actualizado correctamente.');
  }

  Future<void> _runOperation(
    Future<Object?> Function() operation, {
    required String successMessage,
  }) async {
    if (_saving) {
      return;
    }

    setState(() => _saving = true);

    try {
      await operation();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
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
        const SnackBar(content: Text('No se pudo completar la operación.')),
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
      builder: (context, officesSnapshot) {
        if (officesSnapshot.hasError) {
          return _UsersMessage(
            icon: Icons.cloud_off,
            message: _errorMessage(officesSnapshot.error),
          );
        }

        if (!officesSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final offices = officesSnapshot.data!;

        return StreamBuilder<List<UserProfile>>(
          stream: widget.repository.watchUsers(),
          builder: (context, usersSnapshot) {
            if (usersSnapshot.hasError) {
              return _UsersMessage(
                icon: Icons.cloud_off,
                message: _errorMessage(usersSnapshot.error),
              );
            }

            if (!usersSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final users = usersSnapshot.data!;
            final normalizedQuery = _query.trim().toLowerCase();

            final visibleUsers = users
                .where((user) {
                  if (normalizedQuery.isEmpty) {
                    return true;
                  }

                  return user.fullName.toLowerCase().contains(
                        normalizedQuery,
                      ) ||
                      user.email.toLowerCase().contains(normalizedQuery) ||
                      user.employeeCode.toLowerCase().contains(normalizedQuery);
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
                            hintText: 'Buscar por nombre, correo o código',
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
                        onPressed: _saving ? null : () => _createUser(offices),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Nuevo'),
                      ),
                    ],
                  ),
                ),
                if (_saving) const LinearProgressIndicator(),
                Expanded(
                  child: visibleUsers.isEmpty
                      ? const _UsersMessage(
                          icon: Icons.person_search,
                          message: 'No se encontraron trabajadores.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: visibleUsers.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final user = visibleUsers[index];
                            final matchingOffices = offices
                                .where((office) => office.id == user.officeId)
                                .toList(growable: false);

                            final officeName = matchingOffices.isEmpty
                                ? null
                                : matchingOffices.first.name;

                            return _UserCard(
                              user: user,
                              officeName: officeName,
                              isCurrentAdmin:
                                  user.uid == widget.currentAdmin.uid,
                              onEdit: () => _editUser(user, offices),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _errorMessage(Object? error) {
    return error is AdminFailure
        ? error.message
        : 'No se pudo cargar la información administrativa.';
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.officeName,
    required this.isCurrentAdmin,
    required this.onEdit,
  });

  final UserProfile user;
  final String? officeName;
  final bool isCurrentAdmin;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final statusColor = switch (user.status) {
      UserStatus.active => colors.primaryContainer,
      UserStatus.pending => colors.tertiaryContainer,
      UserStatus.inactive => colors.errorContainer,
    };

    final statusForeground = switch (user.status) {
      UserStatus.active => colors.onPrimaryContainer,
      UserStatus.pending => colors.onTertiaryContainer,
      UserStatus.inactive => colors.onErrorContainer,
    };

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: CircleAvatar(
          child: Icon(user.isAdmin ? Icons.admin_panel_settings : Icons.badge),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.fullName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (isCurrentAdmin)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Tooltip(
                  message: 'Tu cuenta',
                  child: Icon(Icons.verified, size: 18),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${user.employeeCode} · ${user.role.label}'),
              Text(user.email),
              Text('Sede: ${officeName ?? user.officeId ?? 'Sin asignar'}'),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    user.status.label,
                    style: TextStyle(
                      color: statusForeground,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        trailing: IconButton(
          tooltip: 'Editar perfil',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
        ),
      ),
    );
  }
}

class _UserFormDialog extends StatefulWidget {
  const _UserFormDialog({
    required this.title,
    required this.offices,
    this.user,
    this.isCreating = false,
    this.lockPrivileges = false,
  });

  final String title;
  final List<Office> offices;
  final UserProfile? user;
  final bool isCreating;
  final bool lockPrivileges;

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _fullNameController;
  late final TextEditingController _employeeCodeController;

  late UserRole _role;
  late UserStatus _status;
  String? _officeId;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();

    final user = widget.user;

    _emailController = TextEditingController(text: user?.email ?? '');
    _passwordController = TextEditingController();
    _fullNameController = TextEditingController(text: user?.fullName ?? '');
    _employeeCodeController = TextEditingController(
      text: user?.employeeCode ?? '',
    );

    _role = user?.role ?? UserRole.employee;
    _status = user?.status ?? UserStatus.pending;
    _officeId = user?.officeId;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _employeeCodeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_role == UserRole.employee &&
        _status == UserStatus.active &&
        _officeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Un trabajador activo debe tener una sede.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _UserFormResult(
        email: widget.isCreating ? _emailController.text.trim() : null,
        password: widget.isCreating ? _passwordController.text : null,
        fullName: _fullNameController.text.trim(),
        employeeCode: _employeeCodeController.text.trim(),
        role: _role,
        status: _status,
        officeId: _officeId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _emailController,
                  readOnly: !widget.isCreating,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';

                    if (!RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(email)) {
                      return 'Ingresa un correo válido.';
                    }

                    return null;
                  },
                ),
                if (widget.isCreating) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Contraseña temporal',
                      prefixIcon: const Icon(Icons.password),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if ((value ?? '').length < 8) {
                        return 'Usa al menos 8 caracteres.';
                      }

                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _fullNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    final name = value?.trim() ?? '';

                    if (name.length < 3 || name.length > 100) {
                      return 'Usa entre 3 y 100 caracteres.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _employeeCodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Código de trabajador',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) {
                    final code = value?.trim() ?? '';

                    if (code.length < 3 || code.length > 30) {
                      return 'Usa entre 3 y 30 caracteres.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<UserRole>(
                  initialValue: _role,
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                    prefixIcon: Icon(Icons.manage_accounts_outlined),
                  ),
                  items: UserRole.values
                      .map(
                        (role) => DropdownMenuItem(
                          value: role,
                          child: Text(role.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: widget.lockPrivileges
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _role = value);
                          }
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<UserStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    prefixIcon: Icon(Icons.verified_user_outlined),
                  ),
                  items: UserStatus.values
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: widget.lockPrivileges
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _status = value);
                          }
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _officeId,
                  decoration: const InputDecoration(
                    labelText: 'Sede asignada',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Sin sede'),
                    ),
                    ...widget.offices.map(
                      (office) => DropdownMenuItem<String?>(
                        value: office.id,
                        child: Text(office.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _officeId = value);
                  },
                ),
                if (widget.lockPrivileges) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Por seguridad no puedes cambiar tu propio rol ni estado.',
                    style: TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
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
          label: Text(widget.isCreating ? 'Registrar' : 'Guardar'),
        ),
      ],
    );
  }
}

class _UserFormResult {
  const _UserFormResult({
    required this.email,
    required this.password,
    required this.fullName,
    required this.employeeCode,
    required this.role,
    required this.status,
    required this.officeId,
  });

  final String? email;
  final String? password;
  final String fullName;
  final String employeeCode;
  final UserRole role;
  final UserStatus status;
  final String? officeId;
}

class _UsersMessage extends StatelessWidget {
  const _UsersMessage({required this.icon, required this.message});

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
