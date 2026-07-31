import 'package:flutter/material.dart';

import 'data.dart';
import 'i18n.dart';
import 'pages.dart';
import 'reference_ui.dart';
import 'store.dart';
import 'theme.dart';

/// One role-safe destination shown by the productivity command centre.
class ProductivityCommand {
  const ProductivityCommand({required this.group, required this.item});

  final MenuGroup group;
  final MenuItem item;
}

/// Returns only commands published by the canonical menu/permission matrix.
///
/// Keeping this as a small public projection makes the permission contract
/// independently testable and prevents the UI from maintaining a second route
/// list that could drift from the sidebar.
List<ProductivityCommand> productivityCommandsFor(SfRole role) => [
  for (final group in menuFor(role))
    for (final item in group.items)
      if (roleCanNavigate(role, item.id))
        ProductivityCommand(group: group, item: item),
];

class ProductivityHub extends StatefulWidget {
  const ProductivityHub({
    super.key,
    required this.role,
    required this.onNavigate,
  });

  final SfRole role;
  final ValueChanged<String> onNavigate;

  @override
  State<ProductivityHub> createState() => _ProductivityHubState();
}

class _ProductivityHubState extends State<ProductivityHub> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ProductivityCommand> get _commands =>
      productivityCommandsFor(widget.role);

  Map<String, ProductivityCommand> get _byRoute => {
    for (final command in _commands) command.item.id: command,
  };

  List<String> get _categories => [
    for (final group in menuFor(widget.role))
      if (group.items.any((item) => roleCanNavigate(widget.role, item.id)))
        group.title,
  ];

  bool _matches(BuildContext context, ProductivityCommand command) {
    if (_category != null && command.group.title != _category) return false;
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    final localizedLabel = menuLabel(context, command.item.label);
    final localizedGroup = grpLabel(context, command.group.title);
    return command.item.id.toLowerCase().contains(query) ||
        command.item.label.toLowerCase().contains(query) ||
        localizedLabel.toLowerCase().contains(query) ||
        command.group.title.toLowerCase().contains(query) ||
        localizedGroup.toLowerCase().contains(query);
  }

  void _open(AppStore store, ProductivityCommand command) {
    if (!roleCanNavigate(widget.role, command.item.id)) return;
    store.rememberOpenedRoute(command.item.id);
    widget.onNavigate(command.item.id);
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final store = AppScope.of(context);
    final commands = _commands;
    final byRoute = _byRoute;
    final filtered = commands
        .where((command) => _matches(context, command))
        .toList(growable: false);
    final favorites = store.favoriteCommandRoutes
        .where((route) => roleCanNavigate(widget.role, route))
        .map((route) => byRoute[route])
        .whereType<ProductivityCommand>()
        .toList(growable: false);
    final recent = store.recentCommandRoutes
        .where((route) => roleCanNavigate(widget.role, route))
        .where((route) => route != 'tools')
        .map((route) => byRoute[route])
        .whereType<ProductivityCommand>()
        .toList(growable: false);
    final grouped = <String, List<ProductivityCommand>>{};
    for (final command in filtered) {
      grouped.putIfAbsent(command.group.title, () => []).add(command);
    }
    final showingQuickSections = _query.trim().isEmpty && _category == null;

    return Scaffold(
      key: const ValueKey('productivity-hub'),
      backgroundColor: c.bg,
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: RefLargeHeader(
              eyebrow: kRoleConfigs[widget.role]!.label,
              title: menuLabel(context, 'Tezkor amallar'),
              subtitle:
                  '${commands.length} ${tr(context, 'quick_actions_subtitle')}',
              actions: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: c.primarySoft,
                    borderRadius: RefRadius.pill,
                  ),
                  child: Text(
                    '${commands.length}',
                    style: RefType.mono(
                      size: 12,
                      weight: FontWeight.w800,
                      color: c.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            sliver: SliverToBoxAdapter(
              child: RefSearchField(
                key: const ValueKey('productivity-search'),
                controller: _search,
                hint: tr(context, 'quick_actions_search'),
                onChanged: (value) => setState(() => _query = value),
                suffix: _query.isEmpty
                    ? null
                    : IconButton(
                        key: const ValueKey('productivity-search-clear'),
                        tooltip: tr(context, 'quick_actions_clear'),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.cancel_rounded),
                      ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                key: const ValueKey('productivity-categories'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _CategoryChip(
                    label: tr(context, 'quick_actions_all'),
                    selected: _category == null,
                    onSelected: () => setState(() => _category = null),
                  ),
                  for (final category in _categories) ...[
                    const SizedBox(width: 7),
                    _CategoryChip(
                      label: grpLabel(context, category),
                      selected: _category == category,
                      onSelected: () => setState(() => _category = category),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (showingQuickSections && favorites.isNotEmpty)
            _CommandSection(
              sectionId: 'favorite',
              title: tr(context, 'quick_actions_favorites'),
              subtitle: tr(context, 'quick_actions_favorites_sub'),
              commands: favorites,
              store: store,
              onOpen: (command) => _open(store, command),
            ),
          if (showingQuickSections && recent.isNotEmpty)
            _CommandSection(
              sectionId: 'recent',
              title: tr(context, 'quick_actions_recent'),
              subtitle: tr(context, 'quick_actions_recent_sub'),
              commands: recent,
              store: store,
              onOpen: (command) => _open(store, command),
            ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.manage_search_rounded,
                        size: 46,
                        color: c.muted2,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr(context, 'quick_actions_empty'),
                        style: RefType.ui(
                          size: 17,
                          weight: FontWeight.w800,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        tr(context, 'quick_actions_empty_sub'),
                        textAlign: TextAlign.center,
                        style: RefType.ui(size: 12, color: c.muted),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            for (final entry in grouped.entries)
              _CommandSection(
                sectionId: 'all',
                title: grpLabel(context, entry.key),
                subtitle: '${entry.value.length} ta bo‘lim',
                commands: entry.value,
                store: store,
                onOpen: (command) => _open(store, command),
              ),
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      selectedColor: c.primarySoft,
      backgroundColor: c.surface,
      side: BorderSide(color: selected ? c.primary : c.border),
      labelStyle: RefType.ui(
        size: 11.5,
        weight: FontWeight.w700,
        color: selected ? c.primaryInk : c.ink2,
      ),
    );
  }
}

class _CommandSection extends StatelessWidget {
  const _CommandSection({
    required this.sectionId,
    required this.title,
    required this.subtitle,
    required this.commands,
    required this.store,
    required this.onOpen,
  });

  final String sectionId;
  final String title;
  final String subtitle;
  final List<ProductivityCommand> commands;
  final AppStore store;
  final ValueChanged<ProductivityCommand> onOpen;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 0),
      sliver: SliverList.list(
        children: [
          RefSectionHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 9),
          for (var index = 0; index < commands.length; index++) ...[
            _CommandTile(
              key: ValueKey(
                'productivity-command-$sectionId-${commands[index].item.id}',
              ),
              command: commands[index],
              sectionId: sectionId,
              favorite: store.isFavoriteCommand(commands[index].item.id),
              onFavorite: () =>
                  store.toggleFavoriteCommand(commands[index].item.id),
              onOpen: () => onOpen(commands[index]),
            ),
            if (index < commands.length - 1) const SizedBox(height: 7),
          ],
        ],
      ),
    );
  }
}

class _CommandTile extends StatelessWidget {
  const _CommandTile({
    super.key,
    required this.command,
    required this.sectionId,
    required this.favorite,
    required this.onFavorite,
    required this.onOpen,
  });

  final ProductivityCommand command;
  final String sectionId;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final label = menuLabel(context, command.item.label);
    return RefSurfaceCard(
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onOpen,
          borderRadius: RefRadius.card,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 5, 9),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.primarySoft,
                    borderRadius: RefRadius.md,
                  ),
                  child: Icon(command.item.icon, size: 20, color: c.primary),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RefType.ui(
                          size: 13.5,
                          weight: FontWeight.w800,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${grpLabel(context, command.group.title)} · /${command.item.id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RefType.ui(size: 10.5, color: c.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: ValueKey(
                    'productivity-favorite-${command.item.id}-$sectionId',
                  ),
                  tooltip: favorite
                      ? tr(context, 'quick_actions_remove_favorite')
                      : tr(context, 'quick_actions_add_favorite'),
                  onPressed: onFavorite,
                  icon: Icon(
                    favorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: favorite ? c.accent : c.muted,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.muted2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
