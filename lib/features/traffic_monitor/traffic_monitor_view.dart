import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/features/traffic_monitor/traffic_monitor_service.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/banner.dart';

String _fmtBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

class TrafficMonitorView extends StatefulWidget {
  const TrafficMonitorView({super.key});

  @override
  State<TrafficMonitorView> createState() => _TrafficMonitorViewState();
}

class _TrafficMonitorViewState extends State<TrafficMonitorView> {
  final _svc = TrafficMonitorService.instance;

  String _range = 'today';
  String _mode = 'proxy';
  bool _billed = true;
  String _tab = 'apps';
  String? _expandedKey;

  late final TextEditingController _deviceCtrl;
  late final TextEditingController _gistIdCtrl;
  late final TextEditingController _tokenCtrl;

  @override
  void initState() {
    super.initState();
    _deviceCtrl = TextEditingController(text: _svc.deviceName);
    _gistIdCtrl = TextEditingController(text: _svc.gistId);
    _tokenCtrl = TextEditingController(text: _svc.gistToken);
    _svc.addListener(_onUpdate);
    unawaited(_svc.refreshAppNames());
  }

  @override
  void dispose() {
    _svc.removeListener(_onUpdate);
    _deviceCtrl.dispose();
    _gistIdCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Widget _chip({
    required String label,
    required bool active,
    required VoidCallback onTap,
    bool center = false,
  }) {
    final cs = context.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: center ? Alignment.center : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? cs.primary : cs.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? cs.onPrimary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final cs = context.colorScheme;
    final sum = _svc.querySummary(_range, _mode, _billed);
    final total = sum.up + sum.down;
    final avgMult = sum.rawTotal > 0 ? total / sum.rawTotal : 1.0;
    final rangeLabel = switch (_range) {
      'today' => '今日',
      '7d' => '近7天',
      '30d' => '近30天',
      _ => '全部',
    };
    final modeLabel = switch (_mode) {
      'proxy' => '代理消耗',
      'direct' => '直连流量',
      _ => '全部流量',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$rangeLabel$modeLabel${_billed && _mode != 'direct' ? '（含倍率）' : ''}',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              Text(
                _svc.deviceName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _fmtBytes(total),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              Text(
                '下载 ${_fmtBytes(sum.down)}',
                style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
              ),
              Text(
                '上传 ${_fmtBytes(sum.up)}',
                style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
              ),
              if (_billed && _mode != 'direct' && sum.rawTotal > 0 && (avgMult - 1.0).abs() > 0.01)
                Text(
                  '原始 ${_fmtBytes(sum.rawTotal)} (均 ${avgMult.toStringAsFixed(2)}x)',
                  style: TextStyle(fontSize: 12.5, color: cs.primary),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankedList(List<TrafficItemStat> items, {required bool expandable}) {
    final cs = context.colorScheme;
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            '当前筛选条件下暂无流量记录',
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
        ),
      );
    }
    final grand = items.fold<int>(0, (acc, e) => acc + e.total);
    final maxTot = items.first.total > 0 ? items.first.total : 1;

    return Column(
      children: [
        for (final item in items.take(60)) ...[
          _buildItemCard(item, grand: grand, maxTot: maxTot, expandable: expandable),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildItemCard(
    TrafficItemStat item, {
    required int grand,
    required int maxTot,
    required bool expandable,
  }) {
    final cs = context.colorScheme;
    final pct = grand > 0 ? (item.total / grand * 100) : 0.0;
    final ratio = (item.total / maxTot).clamp(0.02, 1.0);
    final isExp = expandable && _expandedKey == '$_tab:${item.key}';

    final subParts = <String>[];
    if (_tab == 'nodes') {
      subParts.add('${item.multiplier}x');
      subParts.add('原始 ${_fmtBytes(item.rawTotal)}');
    } else if (item.displayName != item.key) {
      subParts.add(item.key);
    }
    subParts.addAll(item.extra);

    return GestureDetector(
      onTap: expandable
          ? () {
              setState(() {
                _expandedKey = isExp ? null : '$_tab:${item.key}';
              });
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: isExp ? 0.35 : 0.16),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subParts.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subParts.join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _fmtBytes(item.total),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 5,
                width: double.infinity,
                color: cs.primaryContainer.withValues(alpha: 0.4),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(color: cs.primary),
                ),
              ),
            ),
            if (isExp) _buildDrillDown(item),
          ],
        ),
      ),
    );
  }

  Widget _buildDrillDown(TrafficItemStat item) {
    final cs = context.colorScheme;
    final children = _tab == 'apps'
        ? _svc.queryAppDomains(item.key, _range, _mode, _billed)
        : _svc.queryDomainApps(item.key, _range, _mode, _billed);
    if (children.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          '暂无明细',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tab == 'apps' ? '↳ 访问的网站明细' : '↳ 关联应用明细',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 6),
          for (final c in children.take(15))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      c.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _fmtBytes(c.total),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSyncTab() {
    final cs = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        generateSection(
          title: '同步到电脑网页监控面板（GitHub 私有 Gist）',
          items: [
            FormRow(
              title: '设备名称',
              trailing: FormRowTextField(
                controller: _deviceCtrl,
                hintText: 'PHONE',
                autocorrect: false,
              ),
            ),
            FormRow(
              title: 'Gist ID',
              trailing: FormRowTextField(
                controller: _gistIdCtrl,
                hintText: '粘贴私有 Gist ID',
                autocorrect: false,
              ),
            ),
            FormRow(
              title: 'GitHub Token',
              trailing: FormRowTextField(
                controller: _tokenCtrl,
                hintText: 'ghp_...（仅需 gist 权限）',
                obscureText: true,
                autocorrect: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  await _svc.saveSyncSettings(
                    device: _deviceCtrl.text,
                    gist: _gistIdCtrl.text,
                    token: _tokenCtrl.text,
                  );
                  dialogs.showBanner('已保存同步配置', level: BannerLevel.success);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '保存配置',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  await _svc.saveSyncSettings(
                    device: _deviceCtrl.text,
                    gist: _gistIdCtrl.text,
                    token: _tokenCtrl.text,
                  );
                  final ok = await _svc.syncToGist();
                  dialogs.showBanner(
                    ok ? '已同步到云端，电脑面板 1 分钟内可见' : _svc.lastSyncStatus,
                    level: ok ? BannerLevel.success : BannerLevel.error,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _svc.isSyncing ? '同步中...' : '立即同步',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '状态：${_svc.lastSyncStatus}',
          style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          '开启后每 5 分钟自动上传一次汇总，与电脑端 http://127.0.0.1:17890 自动合并显示。',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;
    if (_tab == 'sync') {
      bodyContent = _buildSyncTab();
    } else if (_tab == 'apps') {
      bodyContent = _buildRankedList(
        _svc.queryApps(_range, _mode, _billed),
        expandable: true,
      );
    } else if (_tab == 'domains') {
      bodyContent = _buildRankedList(
        _svc.queryDomains(_range, _mode, _billed),
        expandable: true,
      );
    } else {
      bodyContent = _buildRankedList(
        _svc.queryNodes(_range, _mode, _billed),
        expandable: false,
      );
    }

    return Scaffold(
      title: '流量统计',
      body: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: context.contentTopPadding + 8,
            bottom: 32 + context.bottomInset,
          ),
          children: [
            if (_svc.installedAppsPermissionMissing) ...[
              GestureDetector(
                onTap: () => unawaited(
                  _svc.refreshAppNames(requestPermission: true),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: context.colorScheme.primaryContainer.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '点此授权「读取应用列表」，自动将全部包名显示为中文应用名 →',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: context.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
            _buildSummaryCard(),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  label: '今日',
                  active: _range == 'today',
                  onTap: () => setState(() {
                    _range = 'today';
                    _expandedKey = null;
                  }),
                ),
                _chip(
                  label: '近7天',
                  active: _range == '7d',
                  onTap: () => setState(() {
                    _range = '7d';
                    _expandedKey = null;
                  }),
                ),
                _chip(
                  label: '近30天',
                  active: _range == '30d',
                  onTap: () => setState(() {
                    _range = '30d';
                    _expandedKey = null;
                  }),
                ),
                _chip(
                  label: '全部',
                  active: _range == 'all',
                  onTap: () => setState(() {
                    _range = 'all';
                    _expandedKey = null;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  label: '仅代理',
                  active: _mode == 'proxy',
                  onTap: () => setState(() {
                    _mode = 'proxy';
                    _expandedKey = null;
                  }),
                ),
                _chip(
                  label: '全部',
                  active: _mode == 'all',
                  onTap: () => setState(() {
                    _mode = 'all';
                    _expandedKey = null;
                  }),
                ),
                _chip(
                  label: '仅直连',
                  active: _mode == 'direct',
                  onTap: () => setState(() {
                    _mode = 'direct';
                    _expandedKey = null;
                  }),
                ),
                _chip(
                  label: _billed ? '计费倍率: 开' : '计费倍率: 关',
                  active: _billed,
                  onTap: () => setState(() {
                    _billed = !_billed;
                    _expandedKey = null;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _chip(
                    label: '应用',
                    active: _tab == 'apps',
                    center: true,
                    onTap: () => setState(() {
                      _tab = 'apps';
                      _expandedKey = null;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _chip(
                    label: '网站',
                    active: _tab == 'domains',
                    center: true,
                    onTap: () => setState(() {
                      _tab = 'domains';
                      _expandedKey = null;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _chip(
                    label: '节点',
                    active: _tab == 'nodes',
                    center: true,
                    onTap: () => setState(() {
                      _tab = 'nodes';
                      _expandedKey = null;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _chip(
                    label: '云同步',
                    active: _tab == 'sync',
                    center: true,
                    onTap: () => setState(() {
                      _tab = 'sync';
                      _expandedKey = null;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            bodyContent,
          ],
        ),
      ),
    );
  }
}
