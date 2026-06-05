import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/audio_player_service.dart';

class AudioProgressBar extends StatefulWidget {
  final AudioPlayerService playerService;
  final Color color;

  const AudioProgressBar({super.key, required this.playerService, required this.color});

  @override
  State<AudioProgressBar> createState() => _AudioProgressBarState();
}

class _AudioProgressBarState extends State<AudioProgressBar> {
  Duration _totalDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;
  
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;

  @override
  void initState() {
    super.initState();
    _initListeners();
  }

  void _initListeners() async {
    // 1. Eskuz eskatu iraupena (Abisua galdu badugu berreskuratzeko)
    final duration = await widget.playerService.getDuration();
    if (duration != null && mounted) {
      setState(() => _totalDuration = duration);
    }

    // 2. Stream-ak entzun etengabe posizioa eguneratzeko
    _durationSub = widget.playerService.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _totalDuration = duration);
    });

    _positionSub = widget.playerService.onPositionChanged.listen((position) {
      if (mounted) setState(() => _currentPosition = position);
    });
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    // Segurtasun-neurriak Slider-a ez apurtzeko (Zeroz zatitzea ekiditeko)
    double max = _totalDuration.inMilliseconds.toDouble();
    double val = _currentPosition.inMilliseconds.toDouble();
    
    if (max <= 0) max = 1.0;
    if (val < 0) val = 0.0;
    if (val > max) val = max; // Audioa amaitzean balioa mugatik ez pasatzeko

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            activeColor: widget.color,
            inactiveColor: widget.color.withOpacity(0.2),
            value: val,
            max: max,
            onChanged: (value) {
              widget.playerService.seek(Duration(milliseconds: value.toInt()));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(_currentPosition), style: const TextStyle(fontSize: 10, color: Colors.grey)),
              Text(_formatDuration(_totalDuration), style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }
}