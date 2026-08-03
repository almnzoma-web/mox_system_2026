// ignore_for_file: dead_code

import 'dart:convert';
import 'package:flutter/material.dart';
// ignore: unnecessary_import
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import '../models/marketing_card.dart';
import '../services/storage_service.dart';
import 'welcome_screen.dart';

class ExternalStoreFrontScreen extends StatefulWidget {
  final UserModel? user;
  final List<dynamic> clientCards;
  final String? directMoxId;
  final double? height;

  const ExternalStoreFrontScreen({
    super.key,
    this.user,
    this.clientCards = const [],
    this.directMoxId,
    this.height,
  });

  @override
  State<ExternalStoreFrontScreen> createState() =>
      _ExternalStoreFrontScreenState();
}

class _ExternalStoreFrontScreenState extends State<ExternalStoreFrontScreen> {
  UserModel? _resolvedUser;
  late List<MarketingCard> _resolvedCards;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeStoreData();
  }

  List<MarketingCard> _parseMarketingCards(List<dynamic> rawCards) {
    List<MarketingCard> parsedList = [];
    for (final card in rawCards) {
      try {
        if (card is MarketingCard) {
          parsedList.add(card);
        } else if (card is Map<String, dynamic>) {
          parsedList.add(MarketingCard.fromJson(card));
        } else if (card is Map) {
          parsedList.add(
            MarketingCard.fromJson(Map<String, dynamic>.from(card)),
          );
        } else {
          final dynamic rawJson = (card as dynamic).toJson();
          if (rawJson is Map) {
            parsedList.add(
              MarketingCard.fromJson(Map<String, dynamic>.from(rawJson)),
            );
          }
        }
      } catch (_) {}
    }
    return parsedList;
  }

  Future<void> _initializeStoreData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    UserModel? userToUse = widget.user;
    List<MarketingCard> cardsToUse = _parseMarketingCards(widget.clientCards);
    String? targetMoxId = widget.directMoxId;

    try {
      await StorageService.ensureLoaded();

      // فحص الويب واستخراج الرابط المحدث ومعلمات المعرف فوريًا لمنع ثبات البيانات القديمة
      if (kIsWeb) {
        try {
          final uri = Uri.base;
          final String? queryMox =
              uri.queryParameters['mox'] ?? uri.queryParameters['phone'];
          if (queryMox != null && queryMox.isNotEmpty) {
            targetMoxId = queryMox;
          }

          final String? jsonPayload =
              uri.queryParameters['data'] ?? uri.queryParameters['json'];
          if (jsonPayload != null && jsonPayload.isNotEmpty) {
            final decodedBytes = base64Url.decode(
              base64Url.normalize(jsonPayload),
            );
            final decodedString = utf8.decode(decodedBytes);
            final Map<String, dynamic> parsedJson = json.decode(decodedString);

            if (parsedJson.containsKey('moxId')) {
              targetMoxId = parsedJson['moxId'];
            }
          }
        } catch (_) {}
      }

      if (targetMoxId != null && targetMoxId.isNotEmpty) {
        try {
          final fetchedUser = await StorageService.getUserByMoxId(targetMoxId);
          if (fetchedUser != null) {
            userToUse = fetchedUser;
            final fetchedCards = await StorageService.getClientCards(
              targetMoxId,
            );
            if (fetchedCards.isNotEmpty) {
              cardsToUse = _parseMarketingCards(fetchedCards);
            }
          }
        } catch (_) {}
      }

      if (userToUse != null) {
        try {
          if (userToUse.moxId.isNotEmpty && userToUse.moxId != "لم يحدد") {
            final freshUser = await StorageService.getUserByMoxId(
              userToUse.moxId,
            );
            if (freshUser != null) {
              userToUse = freshUser;
            }
          }
        } catch (_) {}
      }

      if (userToUse != null && userToUse.myAssets.isNotEmpty) {
        final List<MarketingCard> convertedAssets = [];
        for (final asset in userToUse.myAssets) {
          try {
            // ignore: unnecessary_type_check
            if (asset is MarketingCard) {
              convertedAssets.add(asset);
            } else if (asset is Map<String, dynamic>) {
              convertedAssets.add(
                MarketingCard.fromJson(asset as Map<String, dynamic>),
              );
            } else if (asset is Map) {
              convertedAssets.add(
                MarketingCard.fromJson(
                  Map<String, dynamic>.from(asset as Map<dynamic, dynamic>),
                ),
              );
            } else {
              final dynamic rawJson = (asset as dynamic).toJson();
              if (rawJson is Map) {
                convertedAssets.add(
                  MarketingCard.fromJson(Map<String, dynamic>.from(rawJson)),
                );
              } else {
                convertedAssets.add(
                  MarketingCard(
                    title: asset.toString(),
                    description: 'أصل رقمي معتمد في منظومة موكس السيادية',
                    price: 0.0,
                    whatsapp: userToUse.phone,
                    facebookUrl: '',
                  ),
                );
              }
            }
          } catch (_) {}
        }
        if (convertedAssets.isNotEmpty) {
          cardsToUse = convertedAssets;
        }
      }
    } catch (_) {}

    _resolvedUser =
        userToUse ??
        UserModel(
          name: targetMoxId != null ? "متجر العميل الرقمي" : "العميل السيادي",
          phone: "0000000000",
          address: "المتجر الرقمي المفتوح",
          storeDescription: "متجر رقمي معتمد عبر منظومة موكس السيادية",
          moxId: targetMoxId ?? "MOX-ACTIVE",
          password: "",
          balance: 0.0,
          gender: "غير محدد",
          accountType: "external",
        );

    _resolvedCards = cardsToUse.isNotEmpty
        ? cardsToUse
        : [
            MarketingCard(
              title: 'بطاقة المتجر السيادي الافتراضية',
              description:
                  'هذه البطاقة معتمدة وجاهزة للعرض التجاري الفاخر عبر الرابط المنسوخ للزوار.',
              price: 0.0,
              whatsapp: _resolvedUser!.phone,
              facebookUrl: '',
            ),
          ];

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _isStoreActiveAndValid(UserModel activeUser) {
    final String mox = activeUser.moxId;
    final String? gMox = activeUser.guardianMoxId;

    bool hasBasicActivity =
        (mox.trim().isNotEmpty &&
            mox != "لم يحدد" &&
            mox.toLowerCase() != 'null') ||
        (gMox != null &&
            gMox.trim().isNotEmpty &&
            gMox != "لم يحدد" &&
            gMox.toLowerCase() != 'null' &&
            !gMox.startsWith("MOX249-00010001")) ||
        activeUser.phone.isNotEmpty ||
        activeUser.myAssets.isNotEmpty;

    if (!hasBasicActivity) return false;

    if (activeUser.storePublishDate != null &&
        activeUser.storePublishDate!.isNotEmpty) {
      try {
        DateTime publishDate = DateTime.parse(activeUser.storePublishDate!);
        DateTime expiryDate = publishDate.add(const Duration(days: 365));
        if (DateTime.now().isAfter(expiryDate)) {
          return false;
        }
      } catch (_) {}
    }

    return true;
  }

  int _getRemainingDays(UserModel activeUser) {
    if (activeUser.storePublishDate == null ||
        activeUser.storePublishDate!.isEmpty) {
      return 365;
    }
    try {
      DateTime publishDate = DateTime.parse(activeUser.storePublishDate!);
      DateTime expiryDate = publishDate.add(const Duration(days: 365));
      int remaining = expiryDate.difference(DateTime.now()).inDays;
      return remaining > 0 ? remaining : 0;
    } catch (_) {
      return 365;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.height != null &&
        widget.user == null &&
        widget.directMoxId == null &&
        widget.clientCards.isEmpty &&
        !kIsWeb) {
      return Container(height: widget.height, color: Colors.transparent);
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF28A9CC),
          title: const Text(
            "جاري تحديث وتحميل المتجر...",
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF28A9CC)),
        ),
      );
    }

    final UserModel resolvedUser = _resolvedUser!;
    final List<MarketingCard> activeCards = _resolvedCards;
    final bool isStoreActive = _isStoreActiveAndValid(resolvedUser);
    final int remainingDays = _getRemainingDays(resolvedUser);

    Widget content = Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF28A9CC),
        title: Text(
          isStoreActive
              ? "متجر العميل: ${resolvedUser.name}"
              : "المتجر الرقمي السيادي",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
              );
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: isStoreActive
            ? ListView.builder(
                itemCount: activeCards.length + 3,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        border: Border.all(
                          color: const Color(0xFF28A9CC),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                color: Color(0xFF28A9CC),
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "حالة العداد السيادي:",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1B6B80),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF28A9CC),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "متبقي $remainingDays يوم من إجمالي ٣٦٥ يوماً",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else if (index == 1) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF28A9CC), Colors.indigo],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "🌟 السوق المفتوح والواجهة السيادية المعتمدة",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "العميل: ${resolvedUser.name}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "معرف MOX: ${resolvedUser.moxId}",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          if (resolvedUser.address.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              "المجال التجاري: ${resolvedUser.address}",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          // ignore: unnecessary_null_comparison
                          if (resolvedUser.storeDescription != null &&
                              // ignore: unnecessary_non_null_assertion
                              resolvedUser.storeDescription!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                // ignore: unnecessary_non_null_assertion
                                resolvedUser.storeDescription!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  } else if (index == 2) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        "🛒 العروض والبطاقات النشطة للعميل (متاحة للعامة)",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.indigo,
                        ),
                      ),
                    );
                  } else {
                    final int cardIndex = index - 3;
                    final card = activeCards[cardIndex];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    card.title.isNotEmpty
                                        ? card.title
                                        : "بطاقة سيادية",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                ),
                                Text(
                                  "${card.price} ج.س",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              card.description,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      minimumSize: const Size(0, 36),
                                    ),
                                    onPressed: () async {
                                      final phoneNum = card.whatsapp.isNotEmpty
                                          ? card.whatsapp
                                          : resolvedUser.phone;
                                      final url = Uri.parse(
                                        "https://wa.me/$phoneNum",
                                      );
                                      if (await canLaunchUrl(url)) {
                                        await launchUrl(
                                          url,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.shopping_bag_outlined,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    label: const Text(
                                      "طلب عبر واتساب",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      minimumSize: const Size(0, 36),
                                    ),
                                    onPressed: () async {
                                      final detailsUrl = card.facebookUrl;
                                      if (detailsUrl.isNotEmpty) {
                                        final url = Uri.parse(detailsUrl);
                                        if (await canLaunchUrl(url)) {
                                          await launchUrl(
                                            url,
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.link,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    label: const Text(
                                      "المزيد من التفاصيل",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
              )
            : Center(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.gpp_bad_rounded,
                          size: 60,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "⚠️ تنبيه سيادي فاخر: المتجر غير مفعّل",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "عفواً.. هذا العميل لم يقوم حتى الآن بتنشيط متجره، أو انتهت فترة اعتماده السيادي (365 يوماً).",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                            height: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.indigo.shade200),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "💡 هل تمتلك مشروعاً أو دكاناً تجارياً؟",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1B6B80),
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                "انضم الآن إلى منظومة موكس السيادية وافتح متجرك الرقمي المتكامل مع إدارة الرفوف، وتوثيق العقود، والوصول الفوري للعملاء على مدار ٣٦٥ يوماً بكل احترافية وثقة ☕🚬.",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.black54,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF28A9CC),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const WelcomeScreen(),
                              ),
                              (route) => false,
                            );
                          },
                          icon: const Icon(Icons.login, color: Colors.white),
                          label: const Text(
                            "الدخول إلى التطبيق وإنشاء متجرك السيادي",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );

    if (widget.height != null) {
      return SizedBox(height: widget.height, child: content);
    }

    return content;
  }
}
