import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../core/theme.dart';

class CustomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomNavBar(
      {super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTap,
          backgroundColor: Colors.white,
          selectedItemColor: AppTheme.primaryColor,
          unselectedItemColor: Colors.grey,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedHome01,
                color: Colors.grey,
              ),
              activeIcon: HugeIcon(
                icon: HugeIcons.strokeRoundedHome01,
                color: AppTheme.primaryColor,
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedTask01,
                color: Colors.grey,
              ),
              activeIcon: HugeIcon(
                icon: HugeIcons.strokeRoundedTask01,
                color: AppTheme.primaryColor,
              ),
              label: 'Habits',
            ),
            BottomNavigationBarItem(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedCompass01,
                color: Colors.grey,
              ),
              activeIcon: HugeIcon(
                icon: HugeIcons.strokeRoundedCompass01,
                color: AppTheme.primaryColor,
              ),
              label: 'Prayer',
            ),
            BottomNavigationBarItem(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedSettings01,
                color: Colors.grey,
              ),
              activeIcon: HugeIcon(
                icon: HugeIcons.strokeRoundedSettings01,
                color: AppTheme.primaryColor,
              ),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
