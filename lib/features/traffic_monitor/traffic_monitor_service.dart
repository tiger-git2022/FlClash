import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

const _directChains = {'DIRECT', 'REJECT', 'REJECT-DROP', 'PASS', 'COMPATIBLE'};

const _multiPartTlds = {
  'co.jp',
  'ne.jp',
  'or.jp',
  'ac.jp',
  'go.jp',
  'com.cn',
  'net.cn',
  'org.cn',
  'gov.cn',
  'edu.cn',
  'co.uk',
  'org.uk',
  'ac.uk',
  'gov.uk',
  'com.hk',
  'org.hk',
  'edu.hk',
  'com.tw',
  'org.tw',
  'edu.tw',
  'net.tw',
  'com.au',
  'net.au',
  'org.au',
  'com.sg',
  'com.my',
  'co.kr',
  'co.in',
  'com.br',
  'com.mx',
};

final _ipRe = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
final _multRe1 = RegExp(r'(\d+(?:\.\d+)?)\s*[xX×倍](?![a-zA-Z0-9])');
final _multRe2 = RegExp(r'(?<![a-zA-Z0-9])[xX×]\s*(\d+(?:\.\d+)?)(?![a-zA-Z0-9])');

const _builtinAppNames = <String, String>{
  'mihomo': 'FlClash 内核',
  'com.follow.clash': 'FlClash',
  'com.follow.clash.dev': 'FlClash (定制版)',
  'com.google.android.gms': 'Google Play 服务',
  'com.google.android.gsf': 'Google 服务框架',
  'com.android.vending': 'Google Play 商店',
  'com.google.android.youtube': 'YouTube',
  'com.google.android.apps.photos': 'Google 相册',
  'com.google.android.gm': 'Gmail',
  'com.google.android.googlequicksearchbox': 'Google 搜索',
  'com.android.chrome': 'Chrome',
  'com.microsoft.emmx': 'Microsoft Edge',
  'com.microsoft.skydrive': 'OneDrive',
  'com.twitter.android': 'X (Twitter)',
  'org.telegram.messenger': 'Telegram',
  'org.telegram.messenger.web': 'Telegram',
  'com.tencent.mm': '微信',
  'com.tencent.mobileqq': 'QQ',
  'tv.danmaku.bili': '哔哩哔哩',
  'com.bilibili.app.in': 'Bilibili 国际版',
  'moe.tarsin.ehviewer': 'EhViewer',
  'com.hippo.ehviewer': 'EhViewer',
  'com.ehviewer': 'EhViewer',
  'eu.kanade.tachiyomi': 'Tachiyomi / Mihon',
  'app.mihon': 'Mihon',
  'com.openai.chatgpt': 'ChatGPT',
  'com.anthropic.claude': 'Claude',
  'com.discord': 'Discord',
  'com.reddit.frontpage': 'Reddit',
  'jp.pxv.android': 'Pixiv',
  'com.valvesoftware.android.steam.community': 'Steam',
  'com.netflix.mediaclient': 'Netflix',
  'com.spotify.music': 'Spotify',
  'com.github.android': 'GitHub',
};

const _subdomainLabels = <String, String>{
  'daily-cloudcode-pa.googleapis.com': 'Antigravity / Gemini 代码接口',
  'aicode.googleapis.com': 'Google AI 编程接口',
  'jetski-webchannel.googleapis.com': 'Antigravity 实时通道',
  'generativelanguage.googleapis.com': 'Gemini API',
  'fonts.googleapis.com': 'Google 字体',
  'play.googleapis.com': 'Google Play 服务',
  'mtalk.google.com': 'Google 推送通道',
  'video.twimg.com': 'X (Twitter) 视频',
  'pbs.twimg.com': 'X (Twitter) 图片',
  'abs.twimg.com': 'X (Twitter) 静态资源',
  'api.github.com': 'GitHub API',
  'raw.githubusercontent.com': 'GitHub 原始文件',
  'objects.githubusercontent.com': 'GitHub Release 下载',
  'graph.microsoft.com': '微软 Graph API (OneDrive 等)',
};

const _domainLabels = <String, String>{
  'googlevideo.com': 'YouTube 视频流',
  'youtube.com': 'YouTube',
  'youtu.be': 'YouTube 短链',
  'ytimg.com': 'YouTube 封面图',
  'googleapis.com': 'Google API / 服务',
  'gstatic.com': 'Google 静态资源',
  'googleusercontent.com': 'Google 用户文件/云盘',
  'google.com': 'Google 服务',
  'ggpht.com': 'Google / YouTube 图片',
  'gvt1.com': 'Google 下载/更新',
  'gvt2.com': 'Google 下载/更新',
  'twimg.com': 'X (Twitter) 图片/视频',
  'x.com': 'X (Twitter)',
  'twitter.com': 'X (Twitter)',
  't.co': 'X (Twitter) 短链',
  'atlassian.com': 'Atlassian (Jira/Confluence)',
  'atlassian.net': 'Atlassian 云服务',
  'microsoft.com': '微软服务',
  'windows.net': '微软云存储 / OneDrive',
  'azure.com': 'Microsoft Azure',
  'sharepoint.com': 'OneDrive / SharePoint',
  'onedrive.com': 'OneDrive 网盘',
  'live.com': '微软账号 / OneDrive',
  'msedge.net': 'Edge 服务',
  'office.com': 'Microsoft 365 / Office',
  'steamstatic.com': 'Steam 商店图片/视频',
  'steampowered.com': 'Steam 商店',
  'steamcommunity.com': 'Steam 社区',
  'steamserver.net': 'Steam 服务器',
  'github.com': 'GitHub',
  'githubusercontent.com': 'GitHub 文件下载',
  'chatgpt.com': 'ChatGPT',
  'openai.com': 'OpenAI / ChatGPT',
  'oaistatic.com': 'ChatGPT 静态资源',
  'oaiusercontent.com': 'ChatGPT 用户文件',
  'claude.ai': 'Claude AI',
  'anthropic.com': 'Anthropic / Claude',
  'cloudflare.com': 'Cloudflare',
  'amazonaws.com': 'AWS 云服务',
  'cloudfront.net': 'AWS CloudFront CDN',
  'discord.com': 'Discord',
  'discordapp.com': 'Discord',
  'discordapp.net': 'Discord 媒体',
  'telegram.org': 'Telegram',
  't.me': 'Telegram',
  'reddit.com': 'Reddit',
  'redd.it': 'Reddit 媒体',
  'redditmedia.com': 'Reddit 媒体',
  'twitch.tv': 'Twitch 直播',
  'ttvnw.net': 'Twitch 视频流',
  'netflix.com': 'Netflix',
  'nflxvideo.net': 'Netflix 视频流',
  'spotify.com': 'Spotify 音乐',
  'apple.com': 'Apple 服务',
  'icloud.com': 'iCloud',
  'bilibili.com': 'B站 (Bilibili)',
  'hdslb.com': 'B站静态资源',
  'bilivideo.com': 'B站视频流',
  'pixiv.net': 'Pixiv',
  'pximg.net': 'Pixiv 图片',
  'e-hentai.org': 'E-Hentai',
  'exhentai.org': 'ExHentai',
  'ehgt.org': 'E-Hentai 缩略图',
  'hath.network': 'E-Hentai 图床 (H@H)',
  'dmm.co.jp': 'DMM',
  'dlsite.com': 'DLsite',
  'fanbox.cc': 'Pixiv FANBOX',
  'booth.pm': 'BOOTH',
  'nexusmods.com': 'Nexus Mods',
  'wikipedia.org': '维基百科',
  'huggingface.co': 'Hugging Face',
};

const _skipGeositeCats = {
  'cn',
  'private',
  'tld-cn',
  'tld-!cn',
  'gfw',
  'greatfire',
  'win-spy',
  'win-update',
  'win-extra',
  'apple-cn',
  'google-cn',
  'steam@cn',
  'geolocation-cn',
  'geolocation-!cn',
  'alphabet',
};

(int, int) _readVarint(Uint8List buf, int i) {
  var shift = 0;
  var val = 0;
  while (true) {
    final b = buf[i++];
    val |= (b & 0x7F) << shift;
    if ((b & 0x80) == 0) return (val, i);
    shift += 7;
  }
}

Map<String, String> _parseGeositeBytes(Uint8List data) {
  var i = 0;
  final n = data.length;
  final catDomains = <String, List<String>>{};
  try {
    while (i < n) {
      final (tag, i1) = _readVarint(data, i);
      i = i1;
      if ((tag >> 3) == 1 && (tag & 7) == 2) {
        final (ln, i2) = _readVarint(data, i);
        i = i2;
        final end = i + ln;
        var code = '';
        final doms = <String>[];
        while (i < end) {
          final (t2, i3) = _readVarint(data, i);
          i = i3;
          final fn = t2 >> 3;
          final wt = t2 & 7;
          if (fn == 1 && wt == 2) {
            final (l2, i4) = _readVarint(data, i);
            i = i4;
            code = utf8.decode(data.sublist(i, i + l2), allowMalformed: true).toLowerCase();
            i += l2;
          } else if (fn == 2 && wt == 2) {
            final (l2, i4) = _readVarint(data, i);
            i = i4;
            final dEnd = i + l2;
            var dtype = 0;
            var dval = '';
            while (i < dEnd) {
              final (t3, i5) = _readVarint(data, i);
              i = i5;
              final f3 = t3 >> 3;
              final w3 = t3 & 7;
              if (f3 == 1 && w3 == 0) {
                final (v, i6) = _readVarint(data, i);
                dtype = v;
                i = i6;
              } else if (f3 == 2 && w3 == 2) {
                final (l3, i6) = _readVarint(data, i);
                i = i6;
                dval = utf8.decode(data.sublist(i, i + l3), allowMalformed: true).toLowerCase();
                i += l3;
              } else if (w3 == 0) {
                final (_, i6) = _readVarint(data, i);
                i = i6;
              } else if (w3 == 2) {
                final (l3, i6) = _readVarint(data, i);
                i = i6 + l3;
              } else if (w3 == 5) {
                i += 4;
              } else if (w3 == 1) {
                i += 8;
              }
            }
            if ((dtype == 2 || dtype == 3) && dval.isNotEmpty) {
              doms.add(dval);
            }
          } else if (wt == 0) {
            final (_, i4) = _readVarint(data, i);
            i = i4;
          } else if (wt == 2) {
            final (l2, i4) = _readVarint(data, i);
            i = i4 + l2;
          } else if (wt == 5) {
            i += 4;
          } else if (wt == 1) {
            i += 8;
          }
        }
        if (code.isNotEmpty &&
            !code.startsWith('category-') &&
            !code.startsWith('geolocation-') &&
            !_skipGeositeCats.contains(code) &&
            doms.isNotEmpty) {
          catDomains[code] = doms;
        }
      } else {
        final wt = tag & 7;
        if (wt == 0) {
          final (_, i2) = _readVarint(data, i);
          i = i2;
        } else if (wt == 2) {
          final (ln, i2) = _readVarint(data, i);
          i = i2 + ln;
        } else if (wt == 5) {
          i += 4;
        } else if (wt == 1) {
          i += 8;
        }
      }
    }
  } catch (_) {}

  final best = <String, (int, String)>{};
  for (final e in catDomains.entries) {
    final c = e.key.split('@').first.trim();
    if (c.isEmpty) continue;
    final label = _domainLabels['$c.com'] ??
        c
            .split(RegExp(r'[-_]+'))
            .where((s) => s.isNotEmpty)
            .map((s) => s.length <= 2 ? s.toUpperCase() : '${s[0].toUpperCase()}${s.substring(1)}')
            .join(' ');
    final sz = e.value.length;
    for (final d in e.value) {
      final prev = best[d];
      if (prev == null || sz < prev.$1) {
        best[d] = (sz, label);
      }
    }
  }
  return {for (final e in best.entries) e.key: e.value.$2};
}

String extractRootDomain(String host) {
  if (host.isEmpty) return '(未知)';
  final h = host.trim().toLowerCase().replaceAll(RegExp(r'\.+$'), '');
  if (h.contains(':') || _ipRe.hasMatch(h)) return h;
  final parts = h.split('.');
  if (parts.length <= 2) return h;
  final lastTwo = '${parts[parts.length - 2]}.${parts.last}';
  if (_multiPartTlds.contains(lastTwo) && parts.length >= 3) {
    return '${parts[parts.length - 3]}.$lastTwo';
  }
  return lastTwo;
}

double extractNodeMultiplier(String node, bool isProxy) {
  if (!isProxy || node.isEmpty) return 1.0;
  for (final re in [_multRe1, _multRe2]) {
    for (final m in re.allMatches(node)) {
      final v = double.tryParse(m.group(1) ?? '');
      if (v != null && v >= 0.05 && v <= 20.0) {
        return v;
      }
    }
  }
  return 1.0;
}

class _ConnMeta {
  final String app;
  final String host;
  final String root;
  final bool isProxy;
  final String node;
  int lastUp;
  int lastDown;

  _ConnMeta({
    required this.app,
    required this.host,
    required this.root,
    required this.isProxy,
    required this.node,
    required this.lastUp,
    required this.lastDown,
  });
}

class TrafficBucket {
  final String day;
  final String app;
  final String host;
  final String root;
  final bool isProxy;
  final String node;
  int up;
  int down;

  TrafficBucket({
    required this.day,
    required this.app,
    required this.host,
    required this.root,
    required this.isProxy,
    required this.node,
    required this.up,
    required this.down,
  });

  Map<String, dynamic> toJson() => {
    'd': day,
    'a': app,
    'h': host,
    'r': root,
    'p': isProxy ? 1 : 0,
    'n': node,
    'u': up,
    'w': down,
  };

  factory TrafficBucket.fromJson(Map<String, dynamic> j) => TrafficBucket(
    day: (j['d'] ?? '').toString(),
    app: (j['a'] ?? '(未知)').toString(),
    host: (j['h'] ?? '(未知)').toString(),
    root: (j['r'] ?? '(未知)').toString(),
    isProxy: (j['p'] ?? 1) == 1,
    node: (j['n'] ?? '').toString(),
    up: (j['u'] as num?)?.toInt() ?? 0,
    down: (j['w'] as num?)?.toInt() ?? 0,
  );
}

class HourlyTotal {
  final String hour;
  final String day;
  int pu;
  int pd;
  int bpu;
  int bpd;
  int du;
  int dd;

  HourlyTotal({
    required this.hour,
    required this.day,
    this.pu = 0,
    this.pd = 0,
    this.bpu = 0,
    this.bpd = 0,
    this.du = 0,
    this.dd = 0,
  });

  Map<String, dynamic> toJson() => {
    'h': hour,
    'd': day,
    'pu': pu,
    'pd': pd,
    'bpu': bpu,
    'bpd': bpd,
    'du': du,
    'dd': dd,
  };

  factory HourlyTotal.fromJson(Map<String, dynamic> j) => HourlyTotal(
    hour: (j['h'] ?? '').toString(),
    day: (j['d'] ?? '').toString(),
    pu: (j['pu'] as num?)?.toInt() ?? 0,
    pd: (j['pd'] as num?)?.toInt() ?? 0,
    bpu: (j['bpu'] as num?)?.toInt() ?? (j['pu'] as num?)?.toInt() ?? 0,
    bpd: (j['bpd'] as num?)?.toInt() ?? (j['pd'] as num?)?.toInt() ?? 0,
    du: (j['du'] as num?)?.toInt() ?? 0,
    dd: (j['dd'] as num?)?.toInt() ?? 0,
  );
}

class TrafficItemStat {
  final String key;
  final String displayName;
  final int up;
  final int down;
  final int rawTotal;
  final double multiplier;
  final bool isProxy;
  final List<String> extra;

  TrafficItemStat({
    required this.key,
    required this.displayName,
    required this.up,
    required this.down,
    this.rawTotal = 0,
    this.multiplier = 1.0,
    this.isProxy = true,
    this.extra = const [],
  });

  int get total => up + down;
}

class TrafficMonitorService extends ChangeNotifier {
  TrafficMonitorService._();

  static final TrafficMonitorService instance = TrafficMonitorService._();

  bool _initialized = false;
  bool _dirty = false;
  String? _storePath;

  final Map<String, _ConnMeta> _conns = {};
  final Map<String, TrafficBucket> _daily = {};
  final Map<String, HourlyTotal> _hourly = {};
  final Map<String, String> _appNames = {};
  Map<String, String> _geositeMap = {};
  bool installedAppsPermissionMissing = false;

  String deviceName = 'PHONE';
  String gistId = '';
  String gistToken = '';
  String lastSyncStatus = '未配置云同步';
  DateTime? lastSyncAt;
  bool isSyncing = false;

  Timer? _saveTimer;
  Timer? _syncTimer;

  static const _kDeviceName = 'tm_device_name';
  static const _kGistId = 'tm_gist_id';
  static const _kGistToken = 'tm_gist_token';

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      deviceName = (prefs.getString(_kDeviceName) ?? '').trim();
      if (deviceName.isEmpty) deviceName = 'PHONE';
      gistId = (prefs.getString(_kGistId) ?? '').trim();
      gistToken = (prefs.getString(_kGistToken) ?? '').trim();
      if (gistId.isNotEmpty && gistToken.isNotEmpty) {
        lastSyncStatus = '等待首次同步';
      }

      final homeDir = await appPath.homeDirPath;
      _storePath = p.join(homeDir, 'traffic_monitor_data.json');
      await _loadFromDisk();
      unawaited(refreshAppNames());
      unawaited(_loadGeosite(homeDir));

      _saveTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (_dirty) {
          unawaited(_saveToDisk());
        }
      });
      _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        if (gistId.isNotEmpty && gistToken.isNotEmpty) {
          unawaited(syncToGist());
        }
      });
    } catch (_) {}
  }

  Future<void> saveSyncSettings({
    required String device,
    required String gist,
    required String token,
  }) async {
    deviceName = device.trim().isEmpty ? 'PHONE' : device.trim();
    gistId = gist.trim();
    gistToken = token.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDeviceName, deviceName);
    await prefs.setString(_kGistId, gistId);
    await prefs.setString(_kGistToken, gistToken);
    if (gistId.isEmpty || gistToken.isEmpty) {
      lastSyncStatus = '未配置云同步';
    }
    notifyListeners();
  }

  Future<void> _loadGeosite(String homeDir) async {
    try {
      final f = File(p.join(homeDir, 'geosite.dat'));
      if (!await f.exists()) return;
      final bytes = await f.readAsBytes();
      final parsed = await compute(_parseGeositeBytes, bytes);
      if (parsed.isNotEmpty) {
        _geositeMap = parsed;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> refreshAppNames({bool requestPermission = false}) async {
    try {
      final a = app;
      if (a == null) return;
      var granted = await a.isInstalledAppsPermissionGranted();
      if (!granted && requestPermission) {
        granted = await a.requestInstalledAppsPermission();
      }
      installedAppsPermissionMissing = !granted;
      final pkgs = await a.getPackages();
      for (final pkg in pkgs) {
        if (pkg.packageName.isNotEmpty && pkg.label.isNotEmpty) {
          _appNames[pkg.packageName] = pkg.label;
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  String displayNameForApp(String appKey) {
    if (appKey.isEmpty) return '(系统/未知)';
    return _appNames[appKey] ?? _builtinAppNames[appKey] ?? appKey;
  }

  String displayNameForDomain(String domain) {
    if (domain.isEmpty) return '(未知)';
    final d = domain.trim().toLowerCase().replaceAll(RegExp(r'\.+$'), '');
    if (_subdomainLabels.containsKey(d)) return _subdomainLabels[d]!;
    if (_domainLabels.containsKey(d)) return _domainLabels[d]!;
    final root = extractRootDomain(d);
    if (_domainLabels.containsKey(root)) return _domainLabels[root]!;
    if (_geositeMap.containsKey(d)) return _geositeMap[d]!;
    if (_geositeMap.containsKey(root)) return _geositeMap[root]!;
    return domain;
  }

  String _dayStr(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _hourStr(DateTime dt) =>
      '${_dayStr(dt)} ${dt.hour.toString().padLeft(2, '0')}:00';

  void recordRequest(TrackerInfo info) {
    final md = info.metadata;
    var appKey = md.process.trim();
    if (appKey.isEmpty && md.processPath.isNotEmpty) {
      appKey = p.basename(md.processPath);
    }
    if (appKey.isEmpty) {
      appKey = '(系统/未知)';
    }
    final host = md.host.trim().isNotEmpty
        ? md.host.trim()
        : (md.destinationIP.trim().isNotEmpty
              ? md.destinationIP.trim()
              : '(未知)');
    final root = extractRootDomain(host);
    final node = info.chains.isNotEmpty ? info.chains.first : 'DIRECT';
    final isProxy =
        info.chains.isNotEmpty && !_directChains.contains(node.toUpperCase());

    final existing = _conns[info.id];
    if (existing != null) {
      final du = info.upload > existing.lastUp
          ? info.upload - existing.lastUp
          : 0;
      final dd = info.download > existing.lastDown
          ? info.download - existing.lastDown
          : 0;
      existing.lastUp = info.upload;
      existing.lastDown = info.download;
      if (du > 0 || dd > 0) {
        _addDelta(existing, du, dd);
      }
      return;
    }

    final meta = _ConnMeta(
      app: appKey,
      host: host,
      root: root,
      isProxy: isProxy,
      node: node,
      lastUp: info.upload,
      lastDown: info.download,
    );
    _conns[info.id] = meta;
    if (_conns.length > 4000) {
      final drop = _conns.keys.take(1000).toList();
      for (final k in drop) {
        _conns.remove(k);
      }
    }
    if (info.upload > 0 || info.download > 0) {
      _addDelta(meta, info.upload, info.download);
    }
  }

  void recordTraffic(Map<String, RequestTraffic> traffic) {
    if (traffic.isEmpty) return;
    var changed = false;
    for (final entry in traffic.entries) {
      final meta = _conns[entry.key];
      if (meta == null) continue;
      final up = entry.value.upload;
      final dn = entry.value.download;
      final du = up > meta.lastUp ? up - meta.lastUp : 0;
      final dd = dn > meta.lastDown ? dn - meta.lastDown : 0;
      if (up >= meta.lastUp) meta.lastUp = up;
      if (dn >= meta.lastDown) meta.lastDown = dn;
      if (du > 0 || dd > 0) {
        _addDelta(meta, du, dd);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  void _addDelta(_ConnMeta m, int du, int dd) {
    final now = DateTime.now();
    final day = _dayStr(now);
    final hour = _hourStr(now);
    final key = '$day|${m.app}|${m.host}|${m.isProxy ? 1 : 0}|${m.node}';

    final b = _daily[key];
    if (b != null) {
      b.up += du;
      b.down += dd;
    } else {
      _daily[key] = TrafficBucket(
        day: day,
        app: m.app,
        host: m.host,
        root: m.root,
        isProxy: m.isProxy,
        node: m.node,
        up: du,
        down: dd,
      );
    }

    final h = _hourly.putIfAbsent(
      hour,
      () => HourlyTotal(hour: hour, day: day),
    );
    if (m.isProxy) {
      final mult = extractNodeMultiplier(m.node, true);
      h.pu += du;
      h.pd += dd;
      h.bpu += (du * mult).round();
      h.bpd += (dd * mult).round();
    } else {
      h.du += du;
      h.dd += dd;
    }
    _dirty = true;
  }

  void _pruneOldData() {
    final now = DateTime.now();
    final cutDaily = _dayStr(now.subtract(const Duration(days: 90)));
    final cutHourly = _dayStr(now.subtract(const Duration(days: 7)));
    _daily.removeWhere((_, v) => v.day.compareTo(cutDaily) < 0);
    _hourly.removeWhere((_, v) => v.day.compareTo(cutHourly) < 0);
  }

  Map<String, dynamic> buildSyncPayload() {
    _pruneOldData();
    var pu = 0, pd = 0, bpu = 0, bpd = 0, du = 0, dd = 0;
    for (final b in _daily.values) {
      if (b.isProxy) {
        final mult = extractNodeMultiplier(b.node, true);
        pu += b.up;
        pd += b.down;
        bpu += (b.up * mult).round();
        bpd += (b.down * mult).round();
      } else {
        du += b.up;
        dd += b.down;
      }
    }
    final usedApps = <String, String>{};
    for (final b in _daily.values) {
      final dn = displayNameForApp(b.app);
      if (dn.isNotEmpty && dn != b.app) {
        usedApps[b.app] = dn;
      }
    }
    final sortedHourly = _hourly.values.toList()
      ..sort((a, b) => a.hour.compareTo(b.hour));
    return {
      'version': 1,
      'device': deviceName,
      'updatedAt': DateTime.now().toIso8601String().split('.').first,
      'live': {
        'clashConnected': true,
        'controller': 'FlClash Android',
        'activeConns': _conns.length,
      },
      'allTime': {
        'pu': pu,
        'pd': pd,
        'bpu': bpu,
        'bpd': bpd,
        'du': du,
        'dd': dd,
      },
      'appNames': usedApps,
      'hourly': [for (final h in sortedHourly) h.toJson()],
      'daily': [
        for (final b in _daily.values)
          if (b.up + b.down > 0) b.toJson(),
      ],
    };
  }

  Future<void> _saveToDisk() async {
    final path = _storePath;
    if (path == null) return;
    _dirty = false;
    try {
      final payload = buildSyncPayload();
      final tmp = File('$path.tmp');
      await tmp.writeAsString(jsonEncode(payload), flush: true);
      await tmp.rename(path);
    } catch (_) {}
  }

  Future<void> _loadFromDisk() async {
    final path = _storePath;
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) return;
    try {
      final raw = await file.readAsString();
      final doc = jsonDecode(raw) as Map<String, dynamic>;
      final dList = doc['daily'] as List<dynamic>? ?? const [];
      for (final item in dList) {
        if (item is Map<String, dynamic>) {
          final b = TrafficBucket.fromJson(item);
          final key =
              '${b.day}|${b.app}|${b.host}|${b.isProxy ? 1 : 0}|${b.node}';
          _daily[key] = b;
        }
      }
      final hList = doc['hourly'] as List<dynamic>? ?? const [];
      for (final item in hList) {
        if (item is Map<String, dynamic>) {
          final h = HourlyTotal.fromJson(item);
          _hourly[h.hour] = h;
        }
      }
      final names = doc['appNames'] as Map<String, dynamic>? ?? const {};
      for (final e in names.entries) {
        if (e.value is String && (e.value as String).isNotEmpty) {
          _appNames[e.key] = e.value as String;
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> syncToGist() async {
    if (gistId.isEmpty || gistToken.isEmpty) {
      lastSyncStatus = '请先填写 Gist ID 和 GitHub Token';
      notifyListeners();
      return false;
    }
    if (isSyncing) return false;
    isSyncing = true;
    lastSyncStatus = '正在同步...';
    notifyListeners();

    try {
      await _saveToDisk();
      final payload = buildSyncPayload();
      final fileName = 'device-$deviceName.json';
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Authorization': 'Bearer $gistToken',
            'Accept': 'application/vnd.github+json',
          },
        ),
      );
      await dio.patch<void>(
        'https://api.github.com/gists/$gistId',
        data: {
          'files': {
            fileName: {'content': jsonEncode(payload)},
          },
        },
      );
      lastSyncAt = DateTime.now();
      final t = lastSyncAt!;
      lastSyncStatus =
          '同步成功 (${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')})';
      isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      lastSyncStatus = '同步失败: $e';
      isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  String? _startDayForRange(String rangeKey) {
    final now = DateTime.now();
    switch (rangeKey) {
      case 'today':
        return _dayStr(now);
      case '7d':
        return _dayStr(now.subtract(const Duration(days: 6)));
      case '30d':
        return _dayStr(now.subtract(const Duration(days: 29)));
      default:
        return null;
    }
  }

  Iterable<TrafficBucket> _filteredBuckets(String rangeKey, String mode) sync* {
    final start = _startDayForRange(rangeKey);
    for (final b in _daily.values) {
      if (start != null && b.day.compareTo(start) < 0) continue;
      if (mode == 'proxy' && !b.isProxy) continue;
      if (mode == 'direct' && b.isProxy) continue;
      yield b;
    }
  }

  ({int up, int down, int rawTotal}) querySummary(
    String rangeKey,
    String mode,
    bool billed,
  ) {
    var up = 0, down = 0, raw = 0;
    for (final b in _filteredBuckets(rangeKey, mode)) {
      final m = billed ? extractNodeMultiplier(b.node, b.isProxy) : 1.0;
      up += (b.up * m).round();
      down += (b.down * m).round();
      raw += b.up + b.down;
    }
    return (up: up, down: down, rawTotal: raw);
  }

  List<TrafficItemStat> queryApps(String rangeKey, String mode, bool billed) {
    final agg = <String, ({int up, int down, Set<String> doms})>{};
    for (final b in _filteredBuckets(rangeKey, mode)) {
      final m = billed ? extractNodeMultiplier(b.node, b.isProxy) : 1.0;
      final u = (b.up * m).round();
      final d = (b.down * m).round();
      final prev = agg[b.app];
      if (prev == null) {
        agg[b.app] = (up: u, down: d, doms: {b.root});
      } else {
        prev.doms.add(b.root);
        agg[b.app] = (up: prev.up + u, down: prev.down + d, doms: prev.doms);
      }
    }
    final list = [
      for (final e in agg.entries)
        TrafficItemStat(
          key: e.key,
          displayName: displayNameForApp(e.key),
          up: e.value.up,
          down: e.value.down,
          extra: ['${e.value.doms.length} 个网站'],
        ),
    ]..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  List<TrafficItemStat> queryAppDomains(
    String appKey,
    String rangeKey,
    String mode,
    bool billed,
  ) {
    final agg = <String, ({int up, int down})>{};
    for (final b in _filteredBuckets(rangeKey, mode)) {
      if (b.app != appKey) continue;
      final m = billed ? extractNodeMultiplier(b.node, b.isProxy) : 1.0;
      final u = (b.up * m).round();
      final d = (b.down * m).round();
      final prev = agg[b.root];
      agg[b.root] = prev == null
          ? (up: u, down: d)
          : (up: prev.up + u, down: prev.down + d);
    }
    final list = [
      for (final e in agg.entries)
        TrafficItemStat(
          key: e.key,
          displayName: displayNameForDomain(e.key),
          up: e.value.up,
          down: e.value.down,
        ),
    ]..sort((a, b) => b.total.compareTo(a.total));
    return list.take(25).toList();
  }

  List<TrafficItemStat> queryDomains(
    String rangeKey,
    String mode,
    bool billed,
  ) {
    final agg = <String, ({int up, int down, Set<String> apps})>{};
    for (final b in _filteredBuckets(rangeKey, mode)) {
      final m = billed ? extractNodeMultiplier(b.node, b.isProxy) : 1.0;
      final u = (b.up * m).round();
      final d = (b.down * m).round();
      final prev = agg[b.root];
      if (prev == null) {
        agg[b.root] = (up: u, down: d, apps: {displayNameForApp(b.app)});
      } else {
        prev.apps.add(displayNameForApp(b.app));
        agg[b.root] = (up: prev.up + u, down: prev.down + d, apps: prev.apps);
      }
    }
    final list = [
      for (final e in agg.entries)
        TrafficItemStat(
          key: e.key,
          displayName: displayNameForDomain(e.key),
          up: e.value.up,
          down: e.value.down,
          extra: e.value.apps.take(3).toList(),
        ),
    ]..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  List<TrafficItemStat> queryDomainApps(
    String rootDomain,
    String rangeKey,
    String mode,
    bool billed,
  ) {
    final agg = <String, ({int up, int down})>{};
    for (final b in _filteredBuckets(rangeKey, mode)) {
      if (b.root != rootDomain) continue;
      final m = billed ? extractNodeMultiplier(b.node, b.isProxy) : 1.0;
      final u = (b.up * m).round();
      final d = (b.down * m).round();
      final prev = agg[b.app];
      agg[b.app] = prev == null
          ? (up: u, down: d)
          : (up: prev.up + u, down: prev.down + d);
    }
    final list = [
      for (final e in agg.entries)
        TrafficItemStat(
          key: e.key,
          displayName: displayNameForApp(e.key),
          up: e.value.up,
          down: e.value.down,
        ),
    ]..sort((a, b) => b.total.compareTo(a.total));
    return list.take(25).toList();
  }

  List<TrafficItemStat> queryNodes(String rangeKey, String mode, bool billed) {
    final agg = <String, ({int up, int down, int raw, bool isProxy, double mult})>{};
    for (final b in _filteredBuckets(rangeKey, mode)) {
      final mult = extractNodeMultiplier(b.node, b.isProxy);
      final m = billed ? mult : 1.0;
      final u = (b.up * m).round();
      final d = (b.down * m).round();
      final prev = agg[b.node];
      agg[b.node] = prev == null
          ? (
              up: u,
              down: d,
              raw: b.up + b.down,
              isProxy: b.isProxy,
              mult: mult,
            )
          : (
              up: prev.up + u,
              down: prev.down + d,
              raw: prev.raw + b.up + b.down,
              isProxy: prev.isProxy,
              mult: prev.mult,
            );
    }
    final list = [
      for (final e in agg.entries)
        TrafficItemStat(
          key: e.key,
          displayName: e.key,
          up: e.value.up,
          down: e.value.down,
          rawTotal: e.value.raw,
          multiplier: e.value.mult,
          isProxy: e.value.isProxy,
        ),
    ]..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  void disposeTimers() {
    _saveTimer?.cancel();
    _syncTimer?.cancel();
  }
}
