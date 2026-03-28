import 'package:cu_app/Commons/commons.dart';
import 'package:flutter/material.dart';

class ChatCountWidget extends StatelessWidget {
  final int? count;

  const ChatCountWidget({super.key, this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration:
          const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
      child: Text(
        '$count',
        style: Theme.of(context)
            .textTheme
            .bodySmall!
            .copyWith(color: AppColors.white),
      ),
    );
  }
}
