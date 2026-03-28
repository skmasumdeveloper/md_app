import 'package:cu_app/Commons/app_sizes.dart';
import 'package:flutter/material.dart';

import '../Commons/app_colors.dart';
import '../Commons/app_theme_colors.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  final String? labelText;
  final String? errorText;
  final int? minLines;
  final int? maxLines;
  final bool? readOnly;
  final bool? autoFocus;
  final bool? isBorder;
  final bool? obscureText;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final FocusNode? focusNode;
  final bool? isReplying;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged? onChanged;
  final Map<String, dynamic>? replyMessage;
  final VoidCallback? onCancelReply;
  final int? maxLength;

  const CustomTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.labelText = '',
    this.errorText,
    this.minLines,
    this.maxLines,
    this.validator,
    this.readOnly,
    this.keyboardType,
    this.obscureText,
    this.suffixIcon,
    this.prefixIcon,
    this.onChanged,
    this.autoFocus = false,
    this.isBorder = true,
    this.focusNode,
    this.replyMessage,
    this.onCancelReply,
    this.isReplying = false,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      children: [
        TextFormField(
          onTapOutside: (event) {
            FocusScope.of(context).unfocus();
          },
          textCapitalization: TextCapitalization.none,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          readOnly: readOnly ?? false,
          validator: validator,
          obscureText: obscureText ?? false,
          minLines: minLines ?? 1,
          maxLines: maxLines ?? 1,
          keyboardType: keyboardType ?? TextInputType.text,
          cursorColor: AppColors.gradientTwo,
          controller: controller,
          onChanged: onChanged,
          maxLength: maxLength,
          autofocus: autoFocus!,
          focusNode: focusNode,
          style: TextStyle(color: colors.textPrimary),
          decoration: isBorder!
              ? InputDecoration(
                  labelText: (labelText != null && labelText!.isNotEmpty)
                      ? labelText
                      : null,
                  suffixIcon: suffixIcon,
                  prefixIcon: prefixIcon,
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: colors.borderColor),
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                      color: AppColors.gradientTwo,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  border: OutlineInputBorder(
                      borderSide: BorderSide(color: colors.borderColor),
                      borderRadius: BorderRadius.circular(10)),
                  disabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: colors.borderColor),
                      borderRadius: BorderRadius.circular(10)),
                  hintText: hintText ?? '',
                  hintStyle: Theme.of(context).textTheme.bodyMedium,
                  labelStyle: Theme.of(context).textTheme.bodyMedium,
                  errorText: controller.text == "" ? errorText : null)
              : InputDecoration(
                  suffixIcon: suffixIcon,
                  prefixIcon: prefixIcon,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSizes.kDefaultPadding),
                  hintText: hintText ?? '',
                  hintStyle: Theme.of(context).textTheme.bodyMedium,
                  labelStyle: Theme.of(context).textTheme.bodyMedium,
                  errorText: controller.text == "" ? errorText : null),
        ),
      ],
    );
  }
}
