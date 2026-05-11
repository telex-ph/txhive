import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';

class WorkspaceDetailsScreen extends StatefulWidget {
  final String workspaceId;

  const WorkspaceDetailsScreen({
    super.key,
    required this.workspaceId,
  });

  @override
  State<WorkspaceDetailsScreen> createState() => _WorkspaceDetailsScreenState();
}

class _WorkspaceDetailsScreenState extends State<WorkspaceDetailsScreen> {
  Map<String, dynamic>? workspace;
  bool loading = true;
  bool searching = false;
  List<dynamic> searchResults = [];

  final _searchCtrl = TextEditingController();

  static const Color _primary = Color(0xFFA10000);
  static const Color _primaryDark = Color(0xFF650000);
  static const Color _dark = Color(0xFF171717);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _surface = Color(0xFFF7F7F9);
  static const Color _surfaceAlt = Color(0xFFF1F1F4);
  static const Color _textDark = Color(0xFF202020);
  static const Color _textMuted = Color(0xFF8A8A8F);
  static const Color _border = Color(0xFFE9E9ED);
  static const Color _danger = Color(0xFFD32F2F);
  static const Color _success = Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<dynamic> get _members {
    return (workspace?['members'] as List?) ?? <dynamic>[];
  }

  String get _workspaceName {
    return (workspace?['name'] ?? 'Workspace').toString();
  }

  String? get _ownerId {
    final owner = workspace?['owner'];

    if (owner == null) return null;

    if (owner is Map && owner['_id'] != null) {
      return owner['_id'].toString();
    }

    return owner.toString();
  }

  bool get _isAdmin {
    if (workspace == null) return false;

    final currentUserId = context.read<AuthProvider>().user?.id;
    if (currentUserId == null) return false;

    final member = _members.firstWhere(
      (m) {
        final user = m['user'];
        return user != null &&
            user['_id']?.toString() == currentUserId.toString();
      },
      orElse: () => null,
    );

    return member != null && member['role'] == 'admin';
  }

  Future<void> _loadWorkspace() async {
    if (mounted) setState(() => loading = true);

    try {
      final data = await ApiService.get('/workspaces/${widget.workspaceId}');

      if (!mounted) return;

      setState(() {
        workspace = Map<String, dynamic>.from(data);
      });
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _searchUsers(String query) async {
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      setState(() => searchResults = []);
      return;
    }

    setState(() => searching = true);

    try {
      final data = await ApiService.get(
        '/auth/users/search?q=${Uri.encodeComponent(trimmed)}',
      );

      final memberIds = _members
          .map((m) {
            final user = m['user'];
            if (user == null) return null;
            return user['_id']?.toString();
          })
          .whereType<String>()
          .toSet();

      if (!mounted) return;

      setState(() {
        searchResults = (data as List).where((u) {
          return !memberIds.contains(u['_id']?.toString());
        }).toList();
      });
    } catch (e) {
      // ignore search errors silently
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  Future<void> _addMember(String userId, String userName) async {
    try {
      final data = await ApiService.post(
        '/workspaces/${widget.workspaceId}/members',
        {'userId': userId},
      );

      if (!mounted) return;

      setState(() {
        workspace = Map<String, dynamic>.from(data);
        searchResults = searchResults.where((u) {
          return u['_id']?.toString() != userId;
        }).toList();
        _searchCtrl.clear();
      });

      _showSuccess('$userName added to workspace');
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _removeMember(String userId, String userName) async {
    final confirm = await _showConfirmDialog(
      icon: Icons.person_remove_outlined,
      title: 'Remove Member',
      message: 'Remove $userName from this workspace?',
      confirmLabel: 'Remove',
      danger: true,
    );

    if (confirm != true) return;

    try {
      await ApiService.delete(
        '/workspaces/${widget.workspaceId}/members/$userId',
      );

      await _loadWorkspace();

      if (mounted) {
        _showSuccess('$userName removed from workspace');
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _regenerateCode() async {
    final confirm = await _showConfirmDialog(
      icon: Icons.refresh_rounded,
      title: 'Regenerate Invite Code',
      message:
          'The old invite code will stop working. Do you want to continue?',
      confirmLabel: 'Regenerate',
      danger: false,
    );

    if (confirm != true) return;

    try {
      final data = await ApiService.post(
        '/workspaces/${widget.workspaceId}/regenerate-code',
        {},
      );

      if (!mounted) return;

      setState(() {
        workspace!['inviteCode'] = data['inviteCode'];
      });

      _showSuccess('New invite code generated');
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    _showSuccess('$label copied to clipboard');
  }

  Future<bool?> _showConfirmDialog({
    required IconData icon,
    required String title,
    required String message,
    required String confirmLabel,
    required bool danger,
  }) {
    final accent = danger ? _danger : _primary;

    return showDialog<bool>(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: 430,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: accent.withOpacity(0.12),
                  ),
                  child: Icon(icon, color: accent, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textDark,
                          side: const BorderSide(color: _border),
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: danger
                                ? const [_danger, Color(0xFFB71C1C)]
                                : const [_primaryDark, _primary],
                          ),
                        ),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            confirmLabel,
                            style: const TextStyle(
                              color: _white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showError(String msg) {
    _showSnack(
      msg.replaceAll('Exception: ', ''),
      icon: Icons.error_outline_rounded,
      iconColor: _danger,
    );
  }

  void _showSuccess(String msg) {
    _showSnack(
      msg,
      icon: Icons.check_circle_outline_rounded,
      iconColor: _success,
    );
  }

  void _showSnack(
    String msg, {
    required IconData icon,
    required Color iconColor,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: _dark,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  String _initial(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _white,
        foregroundColor: _textDark,
        centerTitle: false,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Workspace Details',
              style: TextStyle(
                color: _textDark,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              loading ? 'Loading workspace...' : _workspaceName,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadWorkspace,
          ),
          const SizedBox(width: 6),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: _primary),
            )
          : workspace == null
              ? _buildEmptyPage(
                  icon: Icons.error_outline_rounded,
                  title: 'Workspace not found',
                  subtitle:
                      'This workspace may have been removed or is unavailable.',
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 940;

        return RefreshIndicator(
          color: _primary,
          onRefresh: _loadWorkspace,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(isWide ? 24 : 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroHeader(isWide),
                    const SizedBox(height: 16),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                _buildInviteCodeCard(),
                                if (_isAdmin) ...[
                                  const SizedBox(height: 16),
                                  _buildAddMemberCard(),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 6,
                            child: _buildMembersCard(),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildInviteCodeCard(),
                          if (_isAdmin) ...[
                            const SizedBox(height: 16),
                            _buildAddMemberCard(),
                          ],
                          const SizedBox(height: 16),
                          _buildMembersCard(),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroHeader(bool isWide) {
    final inviteCode = (workspace?['inviteCode'] ?? '').toString();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isWide ? 24 : 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryDark, _primary, _dark],
          stops: [0.0, 0.52, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.30),
                  ),
                ),
                child: Center(
                  child: Text(
                    _initial(_workspaceName),
                    style: const TextStyle(
                      color: _white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _workspaceName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isAdmin
                          ? 'Manage members, invite code, and workspace access.'
                          : 'View members and workspace invite details.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildHeroPill(
                icon: Icons.group_outlined,
                label: 'Members',
                value: '${_members.length}',
              ),
              _buildHeroPill(
                icon: _isAdmin
                    ? Icons.admin_panel_settings_outlined
                    : Icons.person_outline_rounded,
                label: 'Access',
                value: _isAdmin ? 'Admin' : 'Member',
              ),
              _buildHeroPill(
                icon: Icons.key_rounded,
                label: 'Invite',
                value: inviteCode.isEmpty ? 'No code' : 'Available',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPill({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _white, size: 18),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: _white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInviteCodeCard() {
    final code = (workspace?['inviteCode'] ?? '').toString();

    return _sectionCard(
      icon: Icons.link_rounded,
      title: 'Invite Code',
      subtitle:
          'Share this code with teammates so they can join the workspace.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    code.isEmpty ? 'NO CODE' : code,
                    style: const TextStyle(
                      color: _textDark,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _smallIconButton(
                  icon: Icons.copy_rounded,
                  tooltip: 'Copy invite code',
                  onTap: code.isEmpty
                      ? null
                      : () => _copyToClipboard(code, 'Invite code'),
                ),
              ],
            ),
          ),
          if (_isAdmin) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _regenerateCode,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Regenerate code'),
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddMemberCard() {
    return _sectionCard(
      icon: Icons.person_add_alt_1_rounded,
      title: 'Add Member',
      subtitle:
          'Search users by name or email, then add them to this workspace.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchField(),
          if (searchResults.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...searchResults.map((u) => _buildSearchResultTile(u)),
          ],
          if (_searchCtrl.text.trim().isNotEmpty &&
              !searching &&
              searchResults.isEmpty) ...[
            const SizedBox(height: 14),
            _buildInlineEmpty(
              icon: Icons.search_off_rounded,
              text: 'No users found',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        hintText: 'Search by name or email',
        hintStyle: const TextStyle(color: _textMuted, fontSize: 14),
        prefixIcon: const Icon(Icons.search_rounded, color: _primary),
        suffixIcon: searching
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _primary,
                  ),
                ),
              )
            : _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, color: _textMuted),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => searchResults = []);
                    },
                  )
                : null,
        filled: true,
        fillColor: _surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _primary, width: 1.4),
        ),
      ),
      onChanged: (v) {
        setState(() {});
        Future.delayed(const Duration(milliseconds: 400), () {
          if (_searchCtrl.text == v) {
            _searchUsers(v);
          }
        });
      },
    );
  }

  Widget _buildSearchResultTile(dynamic u) {
    final userId = (u['_id'] ?? '').toString();
    final name = (u['name'] ?? 'Unknown User').toString();
    final email = (u['email'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          _buildAvatar(name, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [_primaryDark, _primary],
              ),
            ),
            child: ElevatedButton.icon(
              onPressed: userId.isEmpty ? null : () => _addMember(userId, name),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: _white,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                minimumSize: const Size(76, 38),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersCard() {
    final members = _members;
    final ownerId = _ownerId;
    final currentUserId = context.read<AuthProvider>().user?.id?.toString();

    return _sectionCard(
      icon: Icons.groups_rounded,
      title: 'Members (${members.length})',
      subtitle: 'View people in this workspace and manage access.',
      child: members.isEmpty
          ? _buildInlineEmpty(
              icon: Icons.group_off_outlined,
              text: 'No members yet',
            )
          : Column(
              children: [
                for (final m in members)
                  _buildMemberTile(
                    m: m,
                    ownerId: ownerId,
                    currentUserId: currentUserId,
                  ),
              ],
            ),
    );
  }

  Widget _buildMemberTile({
    required dynamic m,
    required String? ownerId,
    required String? currentUserId,
  }) {
    final u = m['user'] ?? {};
    final userId = (u['_id'] ?? '').toString();
    final name = (u['name'] ?? 'Unknown User').toString();
    final email = (u['email'] ?? '').toString();
    final status = (u['status'] ?? 'offline').toString();
    final role = (m['role'] ?? 'member').toString();

    final isOwner = ownerId != null && userId == ownerId;
    final isAdmin = role == 'admin';
    final isCurrentUser = currentUserId != null && userId == currentUserId;

    final roleLabel = isOwner
        ? 'Owner'
        : isAdmin
            ? 'Admin'
            : 'Member';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              _buildAvatar(name, radius: 22),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: status == 'online' ? _success : _textMuted,
                    shape: BoxShape.circle,
                    border: Border.all(color: _surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      _buildYouBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  email.isEmpty ? status : email,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _buildRoleBadge(
                      label: roleLabel,
                      highlighted: isOwner || isAdmin,
                    ),
                    _buildStatusBadge(status),
                  ],
                ),
              ],
            ),
          ),
          if (_isAdmin && !isOwner && !isCurrentUser) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Remove member',
              onPressed: () => _removeMember(userId, name),
              icon: const Icon(
                Icons.remove_circle_outline_rounded,
                color: _danger,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(String name, {required double radius}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFF2D7D7),
      child: Text(
        _initial(name),
        style: const TextStyle(
          color: _primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildYouBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _dark,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'You',
        style: TextStyle(
          color: _white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildRoleBadge({
    required String label,
    required bool highlighted,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFFBEAEA) : _surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted ? const Color(0xFFF2CACA) : _border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: highlighted ? _primary : _textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final online = status == 'online';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: online ? const Color(0xFFEAF7EE) : const Color(0xFFEFEFF2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: online ? const Color(0xFFCBEBD3) : const Color(0xFFE1E1E5),
        ),
      ),
      child: Text(
        online ? 'Online' : 'Offline',
        style: TextStyle(
          color: online ? _success : _textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFFFBEAEA),
                  border: Border.all(color: const Color(0xFFF2CACA)),
                ),
                child: Icon(icon, color: _primary, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _textMuted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _smallIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: onTap == null
                ? null
                : const LinearGradient(
                    colors: [_primaryDark, _primary],
                  ),
            color: onTap == null ? _surfaceAlt : null,
          ),
          child: Icon(
            icon,
            color: onTap == null ? _textMuted : _white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildInlineEmpty({
    required IconData icon,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(icon, color: _textMuted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPage({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFBEAEA),
                border: Border.all(color: const Color(0xFFF2CACA)),
              ),
              child: Icon(icon, color: _primary, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textDark,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
