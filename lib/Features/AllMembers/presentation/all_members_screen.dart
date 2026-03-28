import 'package:cu_app/Commons/app_colors.dart';
import 'package:cu_app/Commons/app_theme_colors.dart';
import 'package:cu_app/Features/AllMembers/controller/all_members_controller.dart';
import 'package:cu_app/Features/AllMembers/model/all_members_model.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../../Commons/app_images.dart';
import '../../../Utils/datetime_utils.dart';
import '../../../Widgets/custom_smartrefresher_fotter.dart';
import '../../../Widgets/shimmer_effetct.dart';
import '../../AddContact/presentation/add_contact_screen.dart';

class AllMembersScreen extends StatefulWidget {
  const AllMembersScreen({super.key});

  @override
  State<AllMembersScreen> createState() => _AllMembersScreenState();
}

class _AllMembersScreenState extends State<AllMembersScreen> {
  final TextEditingController searchController = TextEditingController();
  final allMembersController = Get.put(AllMembersController());

  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      allMembersController.limit.value = 20;
      callAfterDelay();
    });

    super.initState();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  callAfterDelay() async {
    await Future.delayed(const Duration(milliseconds: 200), () {
      allMembersController.getAllMembers(isLoadingShow: true);
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
          'All Members',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add,
              color: AppColors.white,
              size: 30,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddContactScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: colors.scaffoldBg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: TextField(
                controller: searchController,
                style: TextStyle(color: colors.textOnHeader),
                decoration: InputDecoration(
                  hintText: 'Search members...',
                  hintStyle:
                      TextStyle(color: colors.textOnHeader.withOpacity(0.7)),
                  prefixIcon: Icon(Icons.search,
                      color: colors.textOnHeader.withOpacity(0.7)),
                  filled: true,
                  fillColor: colors.textOnHeader.withOpacity(0.25),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
                onChanged: (value) async {
                  allMembersController.searchText.value = value.toString();
                  EasyDebounce.debounce(
                      'group-debounce', const Duration(milliseconds: 200),
                      () async {
                    await allMembersController.getAllMembers();
                  });
                },
              ),
            ),
            Expanded(
              child: Obx(() {
                if (allMembersController.isListLoading.value) {
                  return const ShimmerEffectLaoder(
                    numberOfWidget: 20,
                  );
                }

                if (allMembersController.filteredMembersList.isEmpty) {
                  return const Center(
                    child: Text("No Member available"),
                  );
                }

                return SmartRefresher(
                  controller: _refreshController,
                  enablePullDown: true,
                  enablePullUp: true,
                  onRefresh: () async {
                    allMembersController.limit.value = 20;
                    allMembersController.getAllMembers(isLoadingShow: true);
                    _refreshController.refreshCompleted();
                  },
                  onLoading: () async {
                    allMembersController.limit.value += 20;
                    allMembersController.getAllMembers(isLoadingShow: false);
                    _refreshController.loadComplete();
                  },
                  footer: const CustomFooterWidget(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: allMembersController.filteredMembersList.length,
                    itemBuilder: (context, index) {
                      final member =
                          allMembersController.filteredMembersList[index];
                      return _buildMemberCard(member);
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(MemberData member) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colors.shadowColor,
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    member.name?.isNotEmpty == true
                        ? member.name![0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        member.email ?? '',
                        style: TextStyle(
                          color: colors.textTertiary,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: allMembersController
                        .getStatusColor(member.accountStatus)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: allMembersController
                          .getStatusColor(member.accountStatus),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    member.accountStatus ?? 'Unknown',
                    style: TextStyle(
                      color: allMembersController
                          .getStatusColor(member.accountStatus),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Created',
                        style: TextStyle(
                          color: colors.textTertiary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateTimeUtils.utcToLocal(
                            member.createdAt!, 'MMMM dd, yyyy\nh:mm a'),
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: member.userType?.toLowerCase() == 'admin'
                        ? AppColors.primary.withOpacity(0.1)
                        : colors.onlineStatus.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    member.userType ?? 'Member',
                    style: TextStyle(
                      color: member.userType?.toLowerCase() == 'admin'
                          ? AppColors.primary
                          : colors.onlineStatus,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => allMembersController.directChat(member),
                      icon: Icon(
                        Icons.message_outlined,
                        color: colors.idleStatus,
                        size: 20,
                      ),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    IconButton(
                      onPressed: () => allMembersController.editMember(member),
                      icon: Icon(
                        Icons.edit_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    IconButton(
                      onPressed: () =>
                          allMembersController.deleteMember(member),
                      icon: Icon(
                        Icons.delete_outline,
                        color: colors.offlineStatus,
                        size: 20,
                      ),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      style: IconButton.styleFrom(
                        backgroundColor: colors.offlineStatus.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
