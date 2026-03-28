import 'package:cached_network_image/cached_network_image.dart';
import 'package:cu_app/Commons/app_images.dart';
import 'package:cu_app/Commons/commons.dart';
import 'package:cu_app/Commons/app_theme_colors.dart';
import 'package:cu_app/Widgets/custom_divider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../../Utils/datetime_utils.dart';
import '../../../Widgets/custom_smartrefresher_fotter.dart';
import '../../Chat/Presentation/chat_screen.dart';
import '../controller/call_history_controller.dart';
import '../model/call_history_model.dart';

// This screen displays the call history of the user, allowing them to view details of past calls.
class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final CallHistoryController callHistoryController =
      Get.put(CallHistoryController());
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      callHistoryController.fetchCallHistory(isLoadingShow: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
          child: Padding(
            padding: const EdgeInsets.only(top: 30),
            child: SizedBox(
              width: 100,
              height: 100,
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(AppImages.appLogoWhite),
                    fit: BoxFit.contain,
                    opacity: 0.2,
                    filterQuality: FilterQuality.high,
                    alignment: Alignment.center,
                  ),
                ),
              ),
            ),
          ),
        ),
        title: const Text(
          'Call History',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
      ),
      body: Container(
        decoration:
            const BoxDecoration(gradient: AppColors.appBarBottomGradientColor),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: colors.scaffoldBg,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Obx(() {
            if (callHistoryController.isLoading.value) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              );
            }

            if (callHistoryController.callHistoryList.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.call_end,
                      size: 64,
                      color: colors.textTertiary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No call history found',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .copyWith(color: colors.textTertiary),
                    ),
                  ],
                ),
              );
            }

            return SmartRefresher(
              controller: _refreshController,
              enablePullDown: true,
              enablePullUp: true,
              onRefresh: () async {
                callHistoryController.limit.value = 20;
                callHistoryController.fetchCallHistory(isLoadingShow: true);
                _refreshController.refreshCompleted();
              },
              onLoading: () async {
                callHistoryController.limit.value += 20;
                callHistoryController.fetchCallHistory(isLoadingShow: false);
                _refreshController.loadComplete();
              },
              footer: const CustomFooterWidget(),
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
                itemCount: callHistoryController.callHistoryList.length,
                itemBuilder: (context, index) {
                  final call = callHistoryController.callHistoryList[index];
                  return _buildCallHistoryItem(context, call, colors);
                },
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCallHistoryItem(
      BuildContext context, GroupCallHistoryList call, AppThemeColors colors) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ChatScreen(
                  groupId: call.groupId.toString(),
                  isAdmin: false,
                  index: 0,
                )));
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppSizes.cardCornerRadius * 10),
                  child: CachedNetworkImage(
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    imageUrl:
                        '${call.groupDetails?.groupImage}', // No group image in model, keeping empty
                    placeholder: (context, url) => CircleAvatar(
                      radius: 25,
                      backgroundColor: colors.shimmerBase,
                    ),
                    errorWidget: (context, url, error) => CircleAvatar(
                      radius: 25,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        (call.groupDetails?.groupName ?? "G")
                            .substring(0, 1)
                            .toUpperCase(),
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                            color: colors.textOnPrimary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.kDefaultPadding),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        call.groupDetails?.groupName ?? "Unknown Group",
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                            fontWeight: FontWeight.w500,
                            color: colors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            _getCallIcon(call),
                            size: 16,
                            color: _getCallIconColor(call, colors),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_getCallStatusText(call).capitalize} Call',
                            style:
                                Theme.of(context).textTheme.bodySmall!.copyWith(
                                      color: colors.textTertiary,
                                    ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(call.startedAt),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .copyWith(color: colors.textTertiary),
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      onPressed: () {},
                      icon: Icon(
                        call.callType == 'video' ? Icons.videocam : Icons.call,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const CustomDivider(),
        ],
      ),
    );
  }

  IconData _getCallIcon(GroupCallHistoryList call) {
    if (call.missedCalled == true && call.status == 'active') {
      return Icons.add_ic_call;
    }
    if (call.missedCalled == true) {
      return Icons.call_missed;
    } else if (call.callStatus == 'outgoing') {
      return Icons.call_made;
    } else {
      return Icons.call_received;
    }
  }

  Color _getCallIconColor(GroupCallHistoryList call, AppThemeColors colors) {
    if (call.missedCalled == true && call.status == 'active') {
      return colors.idleStatus;
    }
    if (call.missedCalled == true) {
      return colors.offlineStatus;
    } else {
      return AppColors.primary;
    }
  }

  String _getCallStatusText(GroupCallHistoryList call) {
    if (call.callStatus == null) return "Unknown";
    if (call.missedCalled == true && call.status == 'active') {
      return "Incoming";
    }
    if (call.missedCalled == true) {
      return "Missed";
    } else if (call.callStatus == 'outgoing') {
      return "Outgoing";
    } else {
      return "Incoming";
    }
  }

  String _formatTime(String? dateTime) {
    if (dateTime == null) return "";

    try {
      final setDateTime =
          DateTimeUtils.utcToLocal(dateTime, 'yyyy-MM-ddTHH:mm:ss.SSSZ');
      final date = DateTime.parse(setDateTime);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final callDate = DateTime(date.year, date.month, date.day);

      if (callDate == today) {
        return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
      } else if (callDate == yesterday) {
        return "Yesterday";
      } else {
        return "${date.day}/${date.month}/${date.year}";
      }
    } catch (e) {
      return "";
    }
  }
}
