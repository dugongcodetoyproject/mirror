import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) 앱 전체 세로 모드 고정
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final cameras = await availableCameras();
  runApp(AIMirrorApp(cameras: cameras));
}

class AIMirrorApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const AIMirrorApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 거울',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: MirrorScreen(cameras: cameras),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
          child: child!,
        );
      },
    );
  }
}

class MirrorScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const MirrorScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<MirrorScreen> createState() => _MirrorScreenState();
}

class _MirrorScreenState extends State<MirrorScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCameraReady = false;
  bool _isControlsVisible = true;
  bool _isFrozen = false;
  double _zoomLevel = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 8.0;
  double _brightness = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _hideControlsAfterDelay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) return;

    CameraDescription frontCamera = widget.cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => widget.cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _controller!.initialize();

      // 2) 명시적으로 화면 방향 고정 (세로)
      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);

      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();

      setState(() {
        _isCameraReady = true;
      });
    } catch (e) {
      print('카메라 초기화 오류: $e');
    }
  }

  void _hideControlsAfterDelay() {
    Future.delayed(Duration(seconds: 3), () {
      if (mounted && _isControlsVisible) {
        setState(() {
          _isControlsVisible = false;
        });
      }
    });
  }

  void _showControls() {
    setState(() {
      _isControlsVisible = true;
    });
    _hideControlsAfterDelay();
  }

  void _toggleFreeze() {
    setState(() {
      _isFrozen = !_isFrozen;
    });
    HapticFeedback.lightImpact();
  }

  void _onZoomChanged(double zoom) {
    setState(() {
      _zoomLevel = zoom.clamp(_minZoom, _maxZoom);
    });
    _controller?.setZoomLevel(_zoomLevel);
    HapticFeedback.selectionClick();
  }

  void _onBrightnessChanged(double brightness) {
    setState(() {
      _brightness = brightness.clamp(-1.0, 1.0);
    });
    _controller?.setExposureOffset(_brightness);
  }

  Widget _buildZoomControls() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.zoom_out, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.blue,
                inactiveTrackColor: Colors.grey,
                thumbColor: Colors.white,
                overlayColor: Colors.blue.withOpacity(0.2),
                trackHeight: 3.0,
              ),
              child: Slider(
                value: _zoomLevel,
                min: _minZoom,
                max: _maxZoom,
                onChanged: _onZoomChanged,
              ),
            ),
          ),
          SizedBox(width: 10),
          Icon(Icons.zoom_in, color: Colors.white, size: 20),
          SizedBox(width: 15),
          Text(
            '${_zoomLevel.toStringAsFixed(1)}x',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBrightnessControls() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.brightness_low, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.amber,
                inactiveTrackColor: Colors.grey,
                thumbColor: Colors.white,
                overlayColor: Colors.amber.withOpacity(0.2),
                trackHeight: 3.0,
              ),
              child: Slider(
                value: _brightness,
                min: -1.0,
                max: 1.0,
                onChanged: _onBrightnessChanged,
              ),
            ),
          ),
          SizedBox(width: 10),
          Icon(Icons.brightness_high, color: Colors.white, size: 20),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 정지/재생 버튼
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: _isFrozen ? Colors.red : Colors.blue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (_isFrozen ? Colors.red : Colors.blue).withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: IconButton(
              onPressed: _toggleFreeze,
              icon: Icon(
                _isFrozen ? Icons.play_arrow : Icons.pause,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),

          // 카메라 전환 버튼 (향후 확장용)
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.7),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () {
                // 향후 후면 카메라 전환 기능 추가 가능
                HapticFeedback.lightImpact();
              },
              icon: Icon(
                Icons.flip_camera_android,
                color: Colors.white,
                size: 25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraReady || _controller == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.blue),
              SizedBox(height: 20),
              Text(
                '카메라 준비 중...',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onTap: _showControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 카메라 미리보기 (배경으로)
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: _isFrozen
                    ? Container(
                        color: Colors.black.withOpacity(0.5),
                        child: Center(
                          child: Icon(
                            Icons.pause_circle_filled,
                            color: Colors.white.withOpacity(0.7),
                            size: 100,
                          ),
                        ),
                      )
                    : CameraPreview(_controller!),
              ),
            ),

            // 배경 이미지 (거울 프레임)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/background/back-mirror-1.png',
                fit: BoxFit.cover,
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
              ),
            ),

            // 컨트롤 UI
            AnimatedOpacity(
              opacity: _isControlsVisible ? 1.0 : 0.0,
              duration: Duration(milliseconds: 300),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                    ],
                    stops: [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
                child: Column(
                  children: [
                    // 상단 정보
                    SafeArea(
                      bottom: false,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Text(
                                'AI 거울',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (_isFrozen)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Text(
                                  '정지됨',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    Spacer(),

                    // 하단 컨트롤
                    SafeArea(
                      top: false,
                      child: Column(
                        children: [
                          _buildZoomControls(),
                          SizedBox(height: 15),
                          _buildBrightnessControls(),
                          SizedBox(height: 20),
                          _buildActionButtons(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
