import 'package:flutter/material.dart';
import 'package:study_app/studypilot/core/theme/sp_colors.dart';

/// Circular member avatar: photo when available, otherwise initials on the
/// member's stable colour. Falls back to initials if the photo fails.
class SpMemberAvatar extends StatelessWidget {
  final String name;

  /// Stable id used to pick the member colour (defaults to [name]).
  final String? colorSeed;
  final String? photoUrl;
  final double size;
  final Color? color;

  /// Text shown instead of computed initials (e.g. "+3" overflow chip).
  final String? label;

  const SpMemberAvatar({
    super.key,
    required this.name,
    this.colorSeed,
    this.photoUrl,
    this.size = 36,
    this.color,
    this.label,
  });

  static String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bg = color ?? SpColors.memberColor(colorSeed ?? name);
    final initials = Center(
      child: Text(
        label ?? initialsOf(name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.38,
          height: 1,
        ),
      ),
    );

    return Semantics(
      label: name,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: photoUrl == null || photoUrl!.isEmpty
            ? initials
            : Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => initials,
              ),
      ),
    );
  }
}

/// Overlapping row of avatars with a "+N" overflow chip.
class SpAvatarStack extends StatelessWidget {
  final List<({String name, String? id, String? photoUrl})> members;
  final int maxVisible;
  final double size;

  const SpAvatarStack({
    super.key,
    required this.members,
    this.maxVisible = 4,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    final visible = members.take(maxVisible).toList();
    final overflow = members.length - visible.length;
    final step = size * 0.7;
    final count = visible.length + (overflow > 0 ? 1 : 0);

    return SizedBox(
      height: size,
      width: count == 0 ? 0 : step * (count - 1) + size,
      child: Stack(
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: step * i,
              child: SpMemberAvatar(
                name: visible[i].name,
                colorSeed: visible[i].id,
                photoUrl: visible[i].photoUrl,
                size: size,
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: step * visible.length,
              child: SpMemberAvatar(
                name: '$overflow more members',
                label: '+$overflow',
                size: size,
                color: SpColors.slate500,
              ),
            ),
        ],
      ),
    );
  }
}
