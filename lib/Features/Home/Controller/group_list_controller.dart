import 'package:cu_app/Features/Home/Model/group_list_model.dart';
import 'package:get/state_manager.dart';

import '../Repository/group_repo.dart';

// This controller manages the list of groups in the application, including fetching the group list, handling search functionality, and managing loading states.
class GroupListController extends GetxController {
  final _groupListRepo = GroupRepo();
  RxList<GroupModel> groupList = <GroupModel>[].obs;
  RxBool isGroupLiastLoading = false.obs;
  RxBool hasLoadedOnce = false.obs; // Track if initial load has happened
  RxInt limit = 20.obs;
  RxString searchText = "".obs;

// This method updates the search text and fetches the group list based on the search query.
  Future<void> getGroupList({bool isLoadingShow = true}) async {
    try {
      isLoadingShow ? isGroupLiastLoading(true) : isGroupLiastLoading(false);
      var res = await _groupListRepo.groupListService(
          searchQuery: searchText.value, offset: 0, limit: limit.value);
      RxList<GroupModel> listData = <GroupModel>[].obs;

      if (res.data!.success == true) {
        listData.value = res.data!.groupModel!;
        listData.sort((a, b) {
          if (a.lastMessage == null && b.lastMessage != null) {
            return 1;
          } else if (a.lastMessage != null && b.lastMessage == null) {
            return -1;
          } else {
            // Both have lastMessage or both don't have lastMessage, sort by updatedAt
            final aUpdatedAt = DateTime.tryParse(a.updatedAt ?? "");
            final bUpdatedAt = DateTime.tryParse(b.updatedAt ?? "");

            if (aUpdatedAt == null && bUpdatedAt == null) {
              return 0;
            } else if (aUpdatedAt == null) {
              return 1;
            } else if (bUpdatedAt == null) {
              return -1;
            }

            return bUpdatedAt.compareTo(aUpdatedAt); // Descending order
          }
        });
        // groupList filter get list only where isTemp == false as normal groups
        listData =
            listData.where((group) => group.isTemp == false).toList().obs;

        groupList.clear();
        groupList.addAll(listData);
        isGroupLiastLoading(false);
        hasLoadedOnce(true);
      } else {
        groupList.value = [];
        isGroupLiastLoading(false);
        hasLoadedOnce(true);
      }
    } catch (e) {
      isGroupLiastLoading(false);
      hasLoadedOnce(true);
    }
  }

  // refresh group list
  Future<void> refreshGroupList() async {
    // limit.value = 20;
    await getGroupList(isLoadingShow: false);
    print("Group list refreshed");
  }

  @override
  void onInit() {
    // Don't auto-fetch here - let socket connection trigger the fetch
    // This prevents race conditions during login
    super.onInit();
  }
}
