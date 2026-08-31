import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../media_extra_request.dart';

/// Voice option exposed in the picker. IDs match paper2audio.com (kokoro voices).
class Paper2AudioVoice {
  final String id;
  final String label;
  final String group;
  const Paper2AudioVoice(this.id, this.label, this.group);
}

const List<Paper2AudioVoice> kPaper2AudioVoices = [
  Paper2AudioVoice('af_heart', 'Narrator — Bright, engaging (default)', 'US Female'),
  Paper2AudioVoice('af_bella', 'Librarian — Calm, warm', 'US Female'),
  Paper2AudioVoice('af_sarah', 'Reporter — Crisp, articulate', 'US Female'),
  Paper2AudioVoice('af_alloy', 'Professor — Polished, controlled', 'US Female'),
  Paper2AudioVoice('am_echo', 'Orator', 'US Male'),
  Paper2AudioVoice('am_liam', 'Interviewer — Engaging, clear', 'US Male'),
  Paper2AudioVoice('am_puck', 'Teacher — Natural, lively', 'US Male'),
  Paper2AudioVoice('am_michael', 'News Anchor — Polished, deliberate', 'US Male'),
  Paper2AudioVoice('bf_isabella', 'Adviser (F) — Centred, harmonised', 'UK'),
  Paper2AudioVoice('bm_daniel', 'Counsellor (M)', 'UK'),
  Paper2AudioVoice('am_fenrir', 'Fenrir (US M, legacy)', 'Legacy'),
  Paper2AudioVoice('bf_emma', 'Emma (UK F, legacy)', 'Legacy'),
  Paper2AudioVoice('bm_george', 'George (UK M, legacy)', 'Legacy'),
];

class GeneratedAudiobookJob {
  final String runId;
  final String fileName;
  final String voiceId;
  final int createdAt;
  String status;
  double progress;
  String? downloadUrl;
  String? error;
  String? coverPath;

  GeneratedAudiobookJob({
    required this.runId,
    required this.fileName,
    required this.voiceId,
    required this.createdAt,
    this.status = 'pending',
    this.progress = 0,
    this.downloadUrl,
    this.error,
    this.coverPath,
  });

  Map<String, dynamic> toJson() => {
        'runId': runId,
        'fileName': fileName,
        'voiceId': voiceId,
        'createdAt': createdAt,
        'status': status,
        'progress': progress,
        'downloadUrl': downloadUrl,
        'error': error,
        'coverPath': coverPath,
      };

  factory GeneratedAudiobookJob.fromJson(Map<String, dynamic> j) =>
      GeneratedAudiobookJob(
        runId: j['runId'] as String,
        fileName: j['fileName'] as String? ?? 'Untitled.epub',
        voiceId: j['voiceId'] as String? ?? 'af_heart',
        createdAt: j['createdAt'] as int? ?? 0,
        status: j['status'] as String? ?? 'pending',
        progress: (j['progress'] as num?)?.toDouble() ?? 0,
        downloadUrl: j['downloadUrl'] as String?,
        error: j['error'] as String?,
        coverPath: j['coverPath'] as String?,
      );

  bool get isDone => downloadUrl != null && downloadUrl!.isNotEmpty;
  bool get isFailed =>
      status.toLowerCase() == 'failed' ||
      (error != null && error!.isNotEmpty);
}

/// Paper2Audio HTTP in Rust (`anime/paper2audio`); job list persisted in host.
class Paper2AudioService {
  Paper2AudioService._();
  static final Paper2AudioService instance = Paper2AudioService._();

  static const String _prefsKey = 'p2a_jobs_v1';

  final ValueNotifier<List<GeneratedAudiobookJob>> jobs = ValueNotifier([]);
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => GeneratedAudiobookJob.fromJson(e as Map<String, dynamic>))
            .toList();
        jobs.value = list;
      } catch (_) {}
    }
    _loaded = true;
  }

  Future<List<GeneratedAudiobookJob>> getJobs() async {
    await _ensureLoaded();
    return List.unmodifiable(jobs.value);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(jobs.value.map((j) => j.toJson()).toList());
    await prefs.setString(_prefsKey, encoded);
  }

  Future<void> removeJob(String runId) async {
    await _ensureLoaded();
    jobs.value = jobs.value.where((j) => j.runId != runId).toList();
    await _persist();
  }

  Future<GeneratedAudiobookJob> upload({
    required File epub,
    required String voiceId,
    String? fileNameOverride,
  }) async {
    final fileName =
        fileNameOverride ?? epub.path.split(Platform.pathSeparator).last;
    final bytes = await epub.readAsBytes();
    return uploadBytes(bytes: bytes, fileName: fileName, voiceId: voiceId);
  }

  Future<GeneratedAudiobookJob> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    required String voiceId,
    String? coverPath,
  }) async {
    await _ensureLoaded();
    final decoded = await mediaExtraRequest({
      'action': 'p2a_upload',
      'file_name': fileName,
      'voice_id': voiceId,
      'epub_base64': base64Encode(bytes),
    });
    final runId = decoded['run_id'] as String?;
    if (runId == null || runId.isEmpty) {
      throw Exception('Upload: missing runId');
    }

    final job = GeneratedAudiobookJob(
      runId: runId,
      fileName: fileName,
      voiceId: voiceId,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      status: 'pending',
      coverPath: coverPath,
    );
    jobs.value = [job, ...jobs.value];
    await _persist();
    return job;
  }

  Future<GeneratedAudiobookJob?> refreshStatus(String runId) async {
    await _ensureLoaded();
    final idx = jobs.value.indexWhere((j) => j.runId == runId);
    if (idx == -1) return null;
    final job = jobs.value[idx];

    try {
      final decoded = await mediaExtraRequest({
        'action': 'p2a_check_status',
        'run_id': runId,
      });
      job.status = decoded['status'] as String? ?? job.status;
      final pv = (decoded['progress'] as num?)?.toDouble();
      if (pv != null) job.progress = pv;
      final url = decoded['download_url'] as String?;
      if (url != null && url.isNotEmpty) job.downloadUrl = url;

      final next = List<GeneratedAudiobookJob>.from(jobs.value);
      next[idx] = job;
      jobs.value = next;
      await _persist();
      return job;
    } catch (_) {
      return job;
    }
  }

  Future<void> refreshAll() async {
    await _ensureLoaded();
    final pending = jobs.value.where((j) => !j.isDone && !j.isFailed).toList();
    for (final j in pending) {
      await refreshStatus(j.runId);
    }
  }
}
