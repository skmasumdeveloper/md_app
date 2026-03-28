import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../Commons/app_colors.dart';
import '../../../Commons/app_theme_colors.dart';

class PersonalInfoDialog extends StatelessWidget {
  final String name;
  final String email;
  final String mobile;
  final String image;
  final String userType;

  const PersonalInfoDialog({
    Key? key,
    required this.name,
    required this.email,
    required this.mobile,
    this.image = '',
    this.userType = '',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                gradient: AppColors.appBarGradient,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Personal Information',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: colors.textOnHeader, fontWeight: FontWeight.w600),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: colors.cardBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.close,
                          size: 18, color: colors.headerBg),
                    ),
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Avatar with white border
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.headerBg,
                        border: Border.all(color: colors.cardBg, width: 4),
                      ),
                      child: ClipOval(
                        child: image.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: image,
                                width: 92,
                                height: 92,
                                fit: BoxFit.cover,
                                placeholder: (c, u) => const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                                errorWidget: (c, u, e) => Center(
                                  child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '',
                                    style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: colors.textOnPrimary),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '',
                                  style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: colors.textOnPrimary),
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    Text(
                      name,
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.isDark ? const Color(0xFF1A3A4A) : const Color(0xFFEAF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        userType.toUpperCase(),
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: AppColors.blue, fontWeight: FontWeight.w700),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Info cards
                    Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.cardBg,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: colors.shadowColor,
                                  blurRadius: 8,
                                  offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: colors.surfaceBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.email,
                                    color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'EMAIL ADDRESS',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .copyWith(
                                              color: colors.textTertiary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      email,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    )
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.cardBg,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: colors.shadowColor,
                                  blurRadius: 8,
                                  offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: colors.surfaceBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.phone,
                                    color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'MOBILE NUMBER',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .copyWith(
                                              color: colors.textTertiary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      mobile,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    )
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
