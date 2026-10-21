import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'common.dart';

class FeedCard extends StatelessWidget {
  final FeedItem item;
  const FeedCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(path: item.authorPic, name: item.authorName, radius: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      timeAgo(item.createdAt),
                      style: GoogleFonts.poppins(
                          fontSize: 11.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (item.isAnnouncement)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.softBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Announcement',
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy),
                  ),
                )
              else
                StatusChip(item.complaint!.status),
            ],
          ),
          if (item.body.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              item.body,
              style: GoogleFonts.poppins(fontSize: 13.5, height: 1.45),
            ),
          ],
          if (item.photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            PhotoGrid(photos: item.photos),
          ],
        ],
      ),
    );
  }
}

class PhotoGrid extends StatelessWidget {
  final List<String> photos;
  const PhotoGrid({super.key, required this.photos});

  void _open(BuildContext context, int index) {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PhotoViewerScreen(photos: photos, initialIndex: index),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (photos.length == 1) {
      return GestureDetector(
        onTap: () => _open(context, 0),
        child: NetImage(
          path: photos[0],
          width: double.infinity,
          height: 210,
          radius: 14,
        ),
      );
    }
    final shown = photos.take(4).toList();
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 1.25,
      children: [
        for (var i = 0; i < shown.length; i++)
          GestureDetector(
            onTap: () => _open(context, i),
            child: Stack(
              fit: StackFit.expand,
              children: [
                NetImage(path: shown[i], radius: 12),
                if (i == 3 && photos.length > 4)
                  Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0x8C000000),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '+${photos.length - 4}',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class PhotoViewerScreen extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;
  const PhotoViewerScreen({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.photos.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(
            child: Image.network(
              AppConfig.imageUrl(widget.photos[i]),
              fit: BoxFit.contain,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 64),
            ),
          ),
        ),
      ),
    );
  }
}
