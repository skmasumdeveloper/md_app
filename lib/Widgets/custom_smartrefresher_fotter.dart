import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

// This widget provides a custom footer for the SmartRefresher, displaying loading status and retry options.
class CustomFooterWidget extends StatelessWidget {
  const CustomFooterWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return CustomFooter(
      builder: (context, mode) {
        Widget body;
        if (mode == LoadStatus.loading) {
          body = const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator.adaptive(),
            ],
          );
        } else if (mode == LoadStatus.failed) {
          body = GestureDetector(
            onTap: () {
              // Handle retry action here
            },
            child: const Text("Load Failed! Click to retry"),
          );
        } else if (mode == LoadStatus.canLoading) {
          body = const Text("Release to load more");
        } else {
          // Consider adding a check for no more data
          body = const Text("");
        }
        return SizedBox(
          height: 40.0,
          child: Center(
            child: body,
          ),
        );
      },
    );
  }
}
