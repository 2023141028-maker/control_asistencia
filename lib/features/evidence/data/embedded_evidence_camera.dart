import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../../config/app_navigator.dart';
import '../domain/attendance_evidence.dart';
import '../domain/evidence_services.dart';
import '../domain/liveness_validator.dart';

final class EmbeddedEvidenceCamera implements EvidenceCamera {
  const EmbeddedEvidenceCamera({this.requireLiveness = false});

  final bool requireLiveness;

  @override
  Future<CapturedEvidence?> capture() async {
    final context = AppNavigator.key.currentContext;
    if (context == null) {
      throw const EvidenceFailure(
        code: EvidenceFailureCode.captureFailed,
        message: 'La cámara todavía no está disponible.',
      );
    }

    try {
      return await Navigator.of(context).push<CapturedEvidence>(
        MaterialPageRoute<CapturedEvidence>(
          fullscreenDialog: true,
          builder: (_) => _EmbeddedCameraScreen(
            requireLiveness: requireLiveness,
          ),
        ),
      );
    } on EvidenceFailure {
      rethrow;
    } on CameraException catch (error) {
      throw _cameraFailure(error);
    } catch (_) {
      throw const EvidenceFailure(
        code: EvidenceFailureCode.captureFailed,
        message: 'No se pudo abrir la cámara integrada.',
      );
    }
  }

  @override
  Future<CapturedEvidence?> recoverLostCapture() async => null;

  static EvidenceFailure _cameraFailure(CameraException error) {
    final code = error.code.toLowerCase();
    if (code.contains('denied') ||
        code.contains('restricted') ||
        code.contains('permission')) {
      return const EvidenceFailure(
        code: EvidenceFailureCode.cameraPermissionDenied,
        message: 'Debes permitir el acceso a la cámara para continuar.',
      );
    }

    return const EvidenceFailure(
      code: EvidenceFailureCode.captureFailed,
      message: 'La cámara no pudo capturar la fotografía.',
    );
  }
}

class _EmbeddedCameraScreen extends StatefulWidget {
  const _EmbeddedCameraScreen({required this.requireLiveness});

  final bool requireLiveness;

  @override
  State<_EmbeddedCameraScreen> createState() => _EmbeddedCameraScreenState();
}

class _EmbeddedCameraScreenState extends State<_EmbeddedCameraScreen>
    with WidgetsBindingObserver {
  CameraDescription? _description;
  CameraController? _controller;
  Uint8List? _previewBytes;
  DateTime? _capturedAt;
  Object? _initializationError;
  bool _isTakingPicture = false;
  bool _awaitingChallenge = false;
  CapturedEvidence? _neutralEvidence;
  FacePose? _neutralPose;
  late LivenessChallenge _challenge;
  static const _livenessValidator = LivenessValidator();

  @override
  void initState() {
    super.initState();
    _challenge = _newChallenge();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw const EvidenceFailure(
          code: EvidenceFailureCode.captureFailed,
          message: 'El dispositivo no tiene una cámara disponible.',
        );
      }

      final description = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _description = description;
      await _startController(description);
    } catch (error) {
      if (!mounted) return;
      setState(() => _initializationError = error);
    }
  }

  Future<void> _startController(CameraDescription description) async {
    final previous = _controller;
    _controller = null;
    await previous?.dispose();

    final controller = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = controller;
    await controller.initialize();
    await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);

    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() => _initializationError = null);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    final description = _description;

    if (state == AppLifecycleState.inactive &&
        controller != null &&
        controller.value.isInitialized) {
      _controller = null;
      controller.dispose();
    } else if (state == AppLifecycleState.resumed &&
        description != null &&
        (_controller == null || !_controller!.value.isInitialized)) {
      _startController(description).catchError((Object error) {
        if (mounted) setState(() => _initializationError = error);
      });
    }
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isTakingPicture) {
      return;
    }

    setState(() => _isTakingPicture = true);
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      final pose = await _validateSingleFace(
        file.path,
        bytes,
        requireNeutral: !_awaitingChallenge,
      );
      final evidence = CapturedEvidence(
        bytes: bytes,
        capturedAt: DateTime.now().toUtc(),
      );
      EvidencePolicy.validateCapturedEvidence(evidence);
      if (!mounted) return;

      if (widget.requireLiveness && !_awaitingChallenge) {
        setState(() {
          _neutralEvidence = evidence;
          _neutralPose = pose;
          _awaitingChallenge = true;
        });
        return;
      }

      if (widget.requireLiveness) {
        _validateChallenge(pose);
        final neutral = _neutralEvidence;
        if (neutral == null) {
          throw const EvidenceFailure(
            code: EvidenceFailureCode.captureFailed,
            message: 'La prueba de vida debe iniciarse nuevamente.',
          );
        }
        setState(() {
          _previewBytes = neutral.bytes;
          _capturedAt = neutral.capturedAt;
          _awaitingChallenge = false;
        });
        return;
      }

      setState(() {
        _previewBytes = evidence.bytes;
        _capturedAt = evidence.capturedAt;
      });
    } on EvidenceFailure catch (error) {
      _showError(error.message);
    } on CameraException catch (error) {
      _showError(EmbeddedEvidenceCamera._cameraFailure(error).message);
    } catch (_) {
      _showError('No se pudo procesar la fotografía.');
    } finally {
      if (mounted) setState(() => _isTakingPicture = false);
    }
  }

  Future<FacePose> _validateSingleFace(
    String filePath,
    Uint8List bytes, {
    required bool requireNeutral,
  }) async {
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: true,
        enableClassification: true,
        minFaceSize: 0.2,
      ),
    );

    try {
      final faces = await detector.processImage(InputImage.fromFilePath(filePath));
      if (faces.isEmpty) {
        throw const EvidenceFailure(
          code: EvidenceFailureCode.captureFailed,
          message:
              'No se detectó un rostro. Mira de frente a la cámara y usa '
              'buena iluminación.',
        );
      }
      if (faces.length > 1) {
        throw const EvidenceFailure(
          code: EvidenceFailureCode.captureFailed,
          message: 'Debe aparecer una sola persona en la fotografía.',
        );
      }

      final image = await decodeImageFromList(bytes);
      try {
        final face = faces.single;
        final widthRatio = face.boundingBox.width / image.width;
        final heightRatio = face.boundingBox.height / image.height;
        final centerX = face.boundingBox.center.dx / image.width;
        final centerY = face.boundingBox.center.dy / image.height;
        final yaw = face.headEulerAngleY ?? 0;
        final roll = face.headEulerAngleZ ?? 0;

        if (widthRatio < 0.24 || heightRatio < 0.24) {
          throw const EvidenceFailure(
            code: EvidenceFailureCode.captureFailed,
            message: 'Acerca el rostro a la cámara e inténtalo nuevamente.',
          );
        }
        final minimumCenter = requireNeutral ? 0.25 : 0.15;
        final maximumCenter = requireNeutral ? 0.75 : 0.85;
        if (centerX < minimumCenter ||
            centerX > maximumCenter ||
            centerY < 0.15 ||
            centerY > 0.85) {
          throw const EvidenceFailure(
            code: EvidenceFailureCode.captureFailed,
            message: 'Coloca el rostro en el centro de la cámara.',
          );
        }
        final pose = FacePose(yaw: yaw, roll: roll);
        if (requireNeutral && !_livenessValidator.isNeutral(pose)) {
          throw const EvidenceFailure(
            code: EvidenceFailureCode.captureFailed,
            message: 'Mira de frente y mantén la cabeza recta.',
          );
        }
        return pose;
      } finally {
        image.dispose();
      }
    } on EvidenceFailure {
      rethrow;
    } catch (_) {
      throw const EvidenceFailure(
        code: EvidenceFailureCode.captureFailed,
        message: 'No se pudo validar el rostro capturado.',
      );
    } finally {
      await detector.close();
    }
  }

  void _validateChallenge(FacePose pose) {
    final neutral = _neutralPose;
    if (neutral == null) {
      throw const EvidenceFailure(
        code: EvidenceFailureCode.captureFailed,
        message: 'La prueba de vida debe iniciarse nuevamente.',
      );
    }

    final passed = _livenessValidator.validates(
      challenge: _challenge,
      neutral: neutral,
      response: pose,
    );

    if (!passed) {
      throw EvidenceFailure(
        code: EvidenceFailureCode.captureFailed,
        message: '${_challenge.instruction} y vuelve a pulsar el botón.',
      );
    }
  }

  LivenessChallenge _newChallenge() {
    return Random.secure().nextBool()
        ? LivenessChallenge.turnHead
        : LivenessChallenge.tiltHead;
  }

  void _usePicture() {
    final bytes = _previewBytes;
    final capturedAt = _capturedAt;
    if (bytes == null || capturedAt == null) return;
    Navigator.of(context).pop(
      CapturedEvidence(
        bytes: bytes,
        capturedAt: capturedAt,
        livenessVerified: widget.requireLiveness,
        livenessChallenge: widget.requireLiveness ? _challenge.value : null,
      ),
    );
  }

  void _repeatPicture() {
    setState(() {
      _previewBytes = null;
      _capturedAt = null;
      _neutralEvidence = null;
      _neutralPose = null;
      _awaitingChallenge = false;
      _challenge = _newChallenge();
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final previewBytes = _previewBytes;

    return Scaffold(
      appBar: AppBar(title: const Text('Evidencia de asistencia')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.black,
                alignment: Alignment.center,
                child: previewBytes != null
                    ? Image.memory(previewBytes, fit: BoxFit.contain)
                    : _cameraBody(controller),
              ),
            ),
            if (previewBytes == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Text(
                  _instruction,
                  textAlign: TextAlign.center,
                ),
              ),
            if (previewBytes != null && widget.requireLiveness)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_user, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Prueba de vida superada'),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: previewBytes == null
                  ? FilledButton.icon(
                      onPressed: _isTakingPicture ? null : _takePicture,
                      icon: _isTakingPicture
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt),
                      label: Text(
                        _isTakingPicture
                            ? 'Validando...'
                            : _awaitingChallenge
                            ? 'Validar movimiento'
                            : 'Tomar fotografía frontal',
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _repeatPicture,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Repetir'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _usePicture,
                            icon: const Icon(Icons.check),
                            label: const Text('Usar fotografía'),
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

  String get _instruction {
    if (_awaitingChallenge) {
      return '${_challenge.instruction}. Mantén el teléfono quieto y pulsa '
          '“Validar movimiento”.';
    }
    if (widget.requireLiveness) {
      return 'Paso 1 de 2: mira de frente, con el rostro centrado y cercano. '
          'Después se solicitará una acción aleatoria.';
    }
    return 'Debe aparecer un solo rostro, centrado, cercano y mirando de '
        'frente. Las imágenes sin rostro serán rechazadas.';
  }

  Widget _cameraBody(CameraController? controller) {
    final error = _initializationError;
    if (error != null) {
      final message = error is EvidenceFailure
          ? error.message
          : error is CameraException
          ? EmbeddedEvidenceCamera._cameraFailure(error).message
          : 'No se pudo iniciar la cámara.';
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return const CircularProgressIndicator();
    }
    return CameraPreview(controller);
  }
}
