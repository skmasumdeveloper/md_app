import 'package:flutter/material.dart';

// This file contains utility functions to determine the device size and type (mobile or tablet).

bool isMobile(BuildContext context) {
  double screenWidth = MediaQuery.of(context).size.width;
  double screenHeight = MediaQuery.of(context).size.height;
  double threshold = 600.0;
  return screenWidth <= threshold && screenHeight <= threshold;
}

bool isTab(BuildContext context) {
  double screenWidth = MediaQuery.of(context).size.width;
  double screenHeight = MediaQuery.of(context).size.height;
  double threshold = 600.0;
  return screenWidth > threshold || screenHeight > threshold;
}
