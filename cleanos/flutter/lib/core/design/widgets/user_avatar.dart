/// user_avatar.dart — Avatar circular com foto de rede ou iniciais em gradiente.
library;

import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../env/env.dart';
import '../../models/user.dart';
import '../cleanox_colors.dart';

/// Avatar reutilizável: prioriza [User.avatarUrl]; senão iniciais no gradiente.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    super.key,
    required this.user,
    this.radius = 22,
    this.onTap,
  });

  final User? user;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final u = user;
    final url = u?.avatarUrl(Env.pbUrl);
    final initial = u?.initials ?? 'U';

    final child = url == null
        ? _Initials(radius: radius, initial: initial, clx: clx)
        : ClipOval(
            child: CachedNetworkImage(
              imageUrl: url,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  _Initials(radius: radius, initial: initial, clx: clx),
              errorWidget: (_, __, ___) =>
                  _Initials(radius: radius, initial: initial, clx: clx),
            ),
          );

    if (onTap == null) return child;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: child,
      ),
    );
  }
}

/// Avatar a partir de bytes locais (preview no form, antes do upload).
class UserAvatarBytes extends StatelessWidget {
  const UserAvatarBytes({
    super.key,
    required this.bytes,
    this.radius = 36,
    this.fallbackInitial = 'U',
  });

  final List<int>? bytes;
  final double radius;
  final String fallbackInitial;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    if (bytes == null || bytes!.isEmpty) {
      return _Initials(
        radius: radius,
        initial: fallbackInitial,
        clx: clx,
      );
    }
    return ClipOval(
      child: Image.memory(
        bytes is Uint8List
            ? bytes! as Uint8List
            : Uint8List.fromList(bytes!),
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({
    required this.radius,
    required this.initial,
    required this.clx,
  });

  final double radius;
  final String initial;
  final CleanoxColors clx;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [clx.primary, clx.accent],
        ),
        boxShadow: [
          BoxShadow(
            color: clx.primary.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.85,
        ),
      ),
    );
  }
}
