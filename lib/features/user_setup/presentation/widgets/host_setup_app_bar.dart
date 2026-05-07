import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HostSetupAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HostSetupAppBar({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: onBack == null,
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: const Color(0xFF0B0B0C),
      notificationPredicate: (_) => false,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.white,
        systemNavigationBarColor: Colors.black,
      ),
      leading: onBack == null
          ? null
          : IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
            ),
      titleSpacing: onBack == null ? null : 0,
      title: const Text(
        'Host a space',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Color(0xFF0B0B0C),
          fontSize: 20,
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
