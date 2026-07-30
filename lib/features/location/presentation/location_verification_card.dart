import 'package:flutter/material.dart';

import '../../offices/domain/office.dart';
import '../domain/device_location.dart';
import '../domain/geofence_validator.dart';
import '../domain/location_service.dart';

class LocationVerificationCard extends StatefulWidget {
  const LocationVerificationCard({
    required this.office,
    required this.locationService,
    required this.geofenceValidator,
    super.key,
  });

  final Office office;
  final LocationService locationService;
  final GeofenceValidator geofenceValidator;

  @override
  State<LocationVerificationCard> createState() {
    return _LocationVerificationCardState();
  }
}

class _LocationVerificationCardState extends State<LocationVerificationCard> {
  bool _isLoading = false;
  DeviceLocation? _location;
  GeofenceValidationResult? _result;
  LocationFailure? _failure;

  Future<void> _verifyLocation() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _location = null;
      _result = null;
      _failure = null;
    });

    try {
      final location = await widget.locationService.getCurrentLocation();

      final result = widget.geofenceValidator.validate(
        office: widget.office,
        location: location,
      );

      if (!mounted) return;

      setState(() {
        _location = location;
        _result = result;
        _isLoading = false;
      });
    } on LocationFailure catch (error) {
      if (!mounted) return;

      setState(() {
        _failure = error;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _failure = const LocationFailure(
          code: LocationFailureCode.unavailable,
          message: 'Ocurrió un error al verificar la ubicación.',
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _openRequiredSettings(LocationFailureCode failureCode) async {
    var opened = false;

    try {
      if (failureCode == LocationFailureCode.serviceDisabled) {
        opened = await widget.locationService.openLocationSettings();
      } else if (failureCode == LocationFailureCode.permissionDeniedForever ||
          failureCode == LocationFailureCode.preciseLocationRequired) {
        opened = await widget.locationService.openAppSettings();
      }
    } catch (_) {
      opened = false;
    }

    if (!mounted || opened) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se pudo abrir la configuración del dispositivo.'),
      ),
    );
  }

  String? _settingsButtonLabel(LocationFailureCode failureCode) {
    if (failureCode == LocationFailureCode.serviceDisabled) {
      return 'Activar ubicación';
    }

    if (failureCode == LocationFailureCode.permissionDeniedForever ||
        failureCode == LocationFailureCode.preciseLocationRequired) {
      return 'Abrir configuración';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasAttempted = _location != null || _failure != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Validación geográfica',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(widget.office.name),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _LocationMetric(
              label: 'Radio permitido',
              value: '${widget.office.radiusMeters.toStringAsFixed(0)} metros',
            ),
            const SizedBox(height: 8),
            _LocationMetric(
              label: 'Precisión máxima',
              value:
                  '${widget.office.maxAccuracyMeters.toStringAsFixed(0)} metros',
            ),
            const Divider(height: 32),
            if (_isLoading)
              const _LoadingLocationState()
            else if (_failure != null)
              _buildFailure(context, _failure!)
            else if (_location != null && _result != null)
              _buildResult(context, _location!, _result!)
            else
              const _InitialLocationState(),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isLoading ? null : _verifyLocation,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(
                hasAttempted ? 'Verificar nuevamente' : 'Verificar ubicación',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Esta comprobación todavía no registra la asistencia.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailure(BuildContext context, LocationFailure failure) {
    final colors = Theme.of(context).colorScheme;
    final settingsLabel = _settingsButtonLabel(failure.code);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: colors.onErrorContainer,
            size: 42,
          ),
          const SizedBox(height: 10),
          Text(
            failure.message,
            style: TextStyle(
              color: colors.onErrorContainer,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (settingsLabel != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _openRequiredSettings(failure.code),
              icon: const Icon(Icons.settings),
              label: Text(settingsLabel),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResult(
    BuildContext context,
    DeviceLocation location,
    GeofenceValidationResult result,
  ) {
    final colors = Theme.of(context).colorScheme;

    final backgroundColor = result.isAllowed
        ? colors.primaryContainer
        : colors.errorContainer;

    final foregroundColor = result.isAllowed
        ? colors.onPrimaryContainer
        : colors.onErrorContainer;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            result.isAllowed
                ? Icons.check_circle_outline
                : Icons.cancel_outlined,
            color: foregroundColor,
            size: 48,
          ),
          const SizedBox(height: 10),
          Text(
            result.isAllowed ? 'UBICACIÓN PERMITIDA' : 'UBICACIÓN NO PERMITIDA',
            style: TextStyle(
              color: foregroundColor,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            result.message,
            style: TextStyle(color: foregroundColor),
            textAlign: TextAlign.center,
          ),
          const Divider(height: 28),
          _LocationMetric(
            label: 'Distancia',
            value: '${result.distanceMeters.toStringAsFixed(1)} m',
            color: foregroundColor,
          ),
          const SizedBox(height: 8),
          _LocationMetric(
            label: 'Precisión',
            value: '${result.accuracyMeters.toStringAsFixed(1)} m',
            color: foregroundColor,
          ),
          const SizedBox(height: 8),
          _LocationMetric(
            label: 'Coordenadas',
            value:
                '${location.latitude.toStringAsFixed(6)}, '
                '${location.longitude.toStringAsFixed(6)}',
            color: foregroundColor,
          ),
          const SizedBox(height: 8),
          _LocationMetric(
            label: 'Capturada',
            value: _formatDateTime(location.capturedAt),
            color: foregroundColor,
          ),
          if (location.isMocked) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.science_outlined, color: foregroundColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ubicación simulada detectada. Solo puede aceptarse '
                    'durante pruebas de depuración; la versión de producción '
                    'la rechazará.',
                    style: TextStyle(
                      color: foregroundColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InitialLocationState extends StatelessWidget {
  const _InitialLocationState();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Icon(Icons.gps_fixed, size: 46),
        SizedBox(height: 10),
        Text(
          'Presiona el botón para comprobar tu distancia y la precisión '
          'actual del GPS.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _LoadingLocationState extends StatelessWidget {
  const _LoadingLocationState();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        LinearProgressIndicator(),
        SizedBox(height: 14),
        Text('Obteniendo una ubicación precisa…', textAlign: TextAlign.center),
      ],
    );
  }
}

class _LocationMetric extends StatelessWidget {
  const _LocationMetric({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: color)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();

  String twoDigits(int number) => number.toString().padLeft(2, '0');

  return '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}:'
      '${twoDigits(local.second)}';
}
