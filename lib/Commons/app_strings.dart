import 'package:flutter_dotenv/flutter_dotenv.dart';

// This file contains the AppStrings class which holds various string constants used in the application.
class AppStrings {
  static String appName = dotenv.env['APP_NAME'] ?? '';
  static const String license =
      'Software license\n\nAny intellectual or industrial property rights, and any other exclusive rights on software or technical applications embedded in or related to this Application are held by the Owner and/or its licensors.\n\nSubject to Users compliance with and notwithstanding any divergent provision of these Terms,the Owner merely grants Users a revocable, non-exclusive, non-sublicensable and non-transferable license to use the software and/or any other technical means embedded in theService within the scope and for the purposes of this Application and the Service offered.\n\nThis license does not grant Users any rights to access, usage or disclosure of the original source code. All techniques, algorithms, and procedures contained in the software and any documentation thereto related is the Owner\'s or its licensors sole property.\n\nAll rights and license grants to Users shall immediately terminate upon any termination or expiration of the Agreement.\n\nWithout prejudice to the above, under this license Users may download, install, use and run the software on the permitted number of devices, provided that such devices are common and up-to-date in terms of technology and market standards.\n\nThe Owner reserves the right to release updates, fixes and further developments of this Application and/or its related software and to provide them to Users for free. Users may need to download and install such updates to continue using this Application and/or its related software.\n\nNew releases may only be available against payment of a fee.\n\nThe User may download, install, use and run the software on one device.\n\n';
}

class AdminCheck {
  static const String admin = "admin";
  static const String superAdmin = "SuperAdmin";
}
