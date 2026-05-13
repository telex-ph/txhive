import 'package:flutter/material.dart';
import '../services/api_service.dart';

class EodSettingsScreen extends StatefulWidget {
  final String channelId;
  final String channelName;
  final String workspaceId;
  const EodSettingsScreen({
    super.key,
    required this.channelId,
    required this.channelName,
    required this.workspaceId,
  });

  @override
  State<EodSettingsScreen> createState() => _EodSettingsScreenState();
}

class _EodSettingsScreenState extends State<EodSettingsScreen> {
  bool loading = true;
  bool saving = false;
  bool triggering = false;
  bool loadingScheduled = false;

  bool isEodChannel = false;
  bool autoSendOnComplete = true;
  String cutoffTime = '19:00';

  List<String> recipientEmails = [];
  List<dynamic> scheduledToday = [];

  final _newEmailCtrl = TextEditingController();

  static const Color _primary = Color(0xFFA10000);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _surface = Color(0xFFF7F7F9);
  static const Color _textDark = Color(0xFF202020);
  static const Color _textMuted = Color(0xFF8A8A8F);
  static const Color _border = Color(0xFFE9E9ED);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _newEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);
    try {
      final cfg = await ApiService.get('/eod/${widget.channelId}/config');
      isEodChannel = cfg['isEodChannel'] ?? false;
      final c = cfg['eodConfig'] ?? {};
      autoSendOnComplete = c['autoSendOnComplete'] ?? true;
      cutoffTime = c['cutoffTime'] ?? '19:00';
      recipientEmails = List<String>.from(c['summaryRecipientEmails'] ?? []);

      if (isEodChannel) {
        await _loadScheduledToday();
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadScheduledToday() async {
    setState(() => loadingScheduled = true);
    try {
      final data =
          await ApiService.get('/eod/${widget.channelId}/scheduled-today');
      scheduledToday = data['members'] ?? [];
    } catch (e) {
      // ignore — display empty
    } finally {
      if (mounted) setState(() => loadingScheduled = false);
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await ApiService.put('/eod/${widget.channelId}/config', {
        'isEodChannel': isEodChannel,
        'summaryRecipientEmails': recipientEmails,
        'cutoffTime': cutoffTime,
        'autoSendOnComplete': autoSendOnComplete,
      });
      _showSuccess('EOD settings saved');
      if (isEodChannel && scheduledToday.isEmpty) {
        await _loadScheduledToday();
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _triggerNow() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Generate EOD Summary Now?'),
        content: const Text(
          'This will summarize today\'s messages and trigger the GHL webhook regardless of how many have submitted. Continue?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => triggering = true);
    try {
      final result = await ApiService.post(
          '/eod/${widget.channelId}/trigger', {'force': true});
      if (result['skipped'] == true) {
        _showError(result['reason'] ?? 'Skipped');
      } else {
        _showSuccess(
          'EOD generated! ${result['submitterCount']}/${result['expectedCount']} submitted',
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => triggering = false);
    }
  }

  void _addEmail() {
    final email = _newEmailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Enter a valid email');
      return;
    }
    if (recipientEmails.contains(email)) {
      _showError('Email already added');
      return;
    }
    setState(() {
      recipientEmails.add(email);
      _newEmailCtrl.clear();
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg.replaceAll('Exception: ', '')),
          backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: Text('EOD Settings · #${widget.channelName}'),
        actions: [
          if (!loading)
            TextButton.icon(
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text('Save', style: TextStyle(color: Colors.white)),
              onPressed: saving ? null : _save,
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildToggleCard(),
                if (isEodChannel) ...[
                  const SizedBox(height: 12),
                  _buildTrackioInfoCard(),
                  const SizedBox(height: 12),
                  _buildScheduledTodayCard(),
                  const SizedBox(height: 12),
                  _buildRecipientsCard(),
                  const SizedBox(height: 12),
                  _buildCutoffCard(),
                  const SizedBox(height: 12),
                  _buildTriggerCard(),
                ],
              ],
            ),
    );
  }

  Widget _cardWrap({required Widget child}) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _border),
        ),
        color: _white,
        child: child,
      );

  Widget _buildToggleCard() {
    return _cardWrap(
      child: SwitchListTile(
        value: isEodChannel,
        activeColor: _primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: const Text('Enable EOD Channel',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: _textDark, fontSize: 16)),
        subtitle: const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Auto-summarize daily EOD reports using Trackio schedule data',
            style: TextStyle(color: _textMuted, fontSize: 12),
          ),
        ),
        onChanged: (v) => setState(() => isEodChannel = v),
      ),
    );
  }

  Widget _buildTrackioInfoCard() {
    return _cardWrap(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cloud_sync_outlined, color: _primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Connected to Trackio',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  SizedBox(height: 4),
                  Text(
                    'Expected submitters are auto-fetched from Trackio every day. Only employees with a shift today AND who are members of this channel are expected to submit.',
                    style:
                        TextStyle(color: _textMuted, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduledTodayCard() {
    return _cardWrap(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.group, color: _primary, size: 20),
                const SizedBox(width: 8),
                const Text('Scheduled Today',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const Spacer(),
                IconButton(
                  icon: loadingScheduled
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _primary),
                        )
                      : const Icon(Icons.refresh, color: _primary, size: 20),
                  onPressed: loadingScheduled ? null : _loadScheduledToday,
                  tooltip: 'Refresh from Trackio',
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'These members have a shift today per Trackio and are expected to submit',
              style: TextStyle(color: _textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (loadingScheduled)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child:
                    Center(child: CircularProgressIndicator(color: _primary)),
              )
            else if (scheduledToday.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF0D88A)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Color(0xFF8A6700), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No channel members are scheduled today per Trackio',
                        style:
                            TextStyle(color: Color(0xFF8A6700), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...scheduledToday.map((m) {
                final name = m['name'] ?? 'Unknown';
                final email = m['email'] ?? '';
                final initial =
                    (name as String).isNotEmpty ? name[0].toUpperCase() : '?';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFF2D7D7),
                    child: Text(initial,
                        style: const TextStyle(
                            color: _primary, fontWeight: FontWeight.w800)),
                  ),
                  title: Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(email,
                      style: const TextStyle(fontSize: 12, color: _textMuted)),
                  dense: true,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientsCard() {
    return _cardWrap(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.email_outlined, color: _primary, size: 20),
              SizedBox(width: 8),
              Text('Department Head Emails',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ]),
            const SizedBox(height: 4),
            Text(
              'Passed to GHL for the EOD email recipients',
              style: TextStyle(color: _textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _newEmailCtrl,
                  decoration: InputDecoration(
                    hintText: 'head@telex.com',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addEmail(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: _addEmail,
                child: const Text('Add'),
              ),
            ]),
            const SizedBox(height: 12),
            if (recipientEmails.isEmpty)
              const Text('No recipients yet',
                  style: TextStyle(color: _textMuted, fontSize: 13)),
            ...recipientEmails.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                            child:
                                Text(e, style: const TextStyle(fontSize: 13))),
                        IconButton(
                          icon: const Icon(Icons.close,
                              size: 16, color: Colors.red),
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 24, minHeight: 24),
                          onPressed: () =>
                              setState(() => recipientEmails.remove(e)),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildCutoffCard() {
    return _cardWrap(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.schedule, color: _primary, size: 20),
              SizedBox(width: 8),
              Text('Auto-send Settings',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ]),
            const SizedBox(height: 12),
            SwitchListTile(
              value: autoSendOnComplete,
              activeColor: _primary,
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-send when all scheduled members submit',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text(
                  'Triggers immediately once everyone scheduled today has sent their EOD',
                  style: TextStyle(color: _textMuted, fontSize: 12),
                ),
              ),
              onChanged: (v) => setState(() => autoSendOnComplete = v),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cutoff time (Manila)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Send with whoever submitted by this time, even if incomplete',
                  style: TextStyle(color: _textMuted, fontSize: 12),
                ),
              ),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _surface,
                  foregroundColor: _primary,
                  elevation: 0,
                  side: const BorderSide(color: _border),
                ),
                onPressed: () async {
                  final parts = cutoffTime.split(':');
                  final initial = TimeOfDay(
                    hour: int.parse(parts[0]),
                    minute: int.parse(parts[1]),
                  );
                  final picked = await showTimePicker(
                      context: context, initialTime: initial);
                  if (picked != null) {
                    setState(() {
                      cutoffTime =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    });
                  }
                },
                child: Text(cutoffTime,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTriggerCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _primary),
      ),
      color: const Color(0xFFFBEAEA),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.flash_on, color: _primary, size: 20),
              SizedBox(width: 8),
              Text('Manual Trigger',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ]),
            const SizedBox(height: 4),
            const Text(
              'Generate today\'s EOD summary immediately and send to GHL. Useful for testing or end-of-day override.',
              style: TextStyle(color: _textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: triggering
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send),
                label: Text(
                    triggering ? 'Generating...' : 'Generate EOD Summary Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: triggering ? null : _triggerNow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
