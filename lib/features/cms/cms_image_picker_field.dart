part of 'cms_screen.dart';

class _ImagePickerField extends StatefulWidget {
  const _ImagePickerField({
    required this.api,
    required this.parkSlug,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onUploaded,
  });

  final CmsApi api;
  final String parkSlug;
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final Future<void> Function(String url)? onUploaded;

  @override
  State<_ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends State<_ImagePickerField> {
  bool _uploading = false;
  String? _error;
  Uint8List? _preview;
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _ImagePickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parkSlug != widget.parkSlug) {
      _preview = null;
      _error = null;
    }
    if (oldWidget.value != widget.value &&
        _urlController.text != widget.value) {
      _urlController.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
      if (widget.value.isEmpty) _preview = null;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (file == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        throw const CmsApiException('Choose an image under 5 MB.');
      }
      final url = await widget.api.uploadImage(widget.parkSlug, file);
      if (mounted) {
        setState(() => _preview = bytes);
        _urlController.value = TextEditingValue(
          text: url,
          selection: TextSelection.collapsed(offset: url.length),
        );
      }
      widget.onChanged(url);
      await widget.onUploaded?.call(url);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _clear() {
    setState(() {
      _preview = null;
      _error = null;
      _urlController.clear();
    });
    widget.onChanged('');
  }

  String _absolute(String path) => Uri.tryParse(path)?.hasScheme == true
      ? path
      : '${widget.api.baseUrl}${path.startsWith('/') ? '' : '/'}$path';

  @override
  Widget build(BuildContext context) {
    final hasImage = _preview != null || widget.value.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: _ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (hasImage)
              const _CmsPillBadge(
                label: 'Ready',
                foreground: wonderlaSuccess,
                background: Color(0xFFECF9F2),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: wonderlaCream,
            border: Border.all(color: wonderlaBorder),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: wonderlaWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: wonderlaBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: _preview != null
                    ? Image.memory(_preview!, fit: BoxFit.cover)
                    : widget.value.trim().isEmpty
                    ? const Icon(
                        Icons.add_photo_alternate_outlined,
                        color: _brandNavy,
                        size: 28,
                      )
                    : Image.network(
                        _absolute(widget.value.trim()),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          color: wonderlaMuted,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasImage ? 'Image attached' : 'No image selected',
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasImage
                          ? widget.value.trim()
                          : 'PNG, JPG, WebP or GIF · max 5 MB',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: wonderlaMuted,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _uploading ? null : _pick,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: wonderlaWhite,
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          icon: _uploading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.upload_rounded, size: 16),
                          label: Text(
                            _uploading
                                ? 'Uploading…'
                                : hasImage
                                ? 'Replace'
                                : 'Upload image',
                          ),
                        ),
                        if (hasImage && !_uploading)
                          TextButton.icon(
                            onPressed: _clear,
                            style: TextButton.styleFrom(
                              foregroundColor: wonderlaFlagRed,
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            icon: const Icon(Icons.close_rounded, size: 15),
                            label: const Text('Remove'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          _CmsAlertBanner(
            message: _error!,
            tone: _CmsBannerTone.error,
            onDismiss: () => setState(() => _error = null),
          ),
        ],
        const SizedBox(height: 8),
        TextFormField(
          controller: _urlController,
          onChanged: (value) {
            if (_preview != null) setState(() => _preview = null);
            widget.onChanged(value);
          },
          decoration: const InputDecoration(
            labelText: 'Or paste an image URL',
            prefixIcon: Icon(Icons.link_rounded, size: 18),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

class _VideoPickerField extends StatefulWidget {
  const _VideoPickerField({
    required this.api,
    required this.parkSlug,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onUploaded,
  });

  final CmsApi api;
  final String parkSlug;
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final Future<void> Function(String url)? onUploaded;

  @override
  State<_VideoPickerField> createState() => _VideoPickerFieldState();
}

class _VideoPickerFieldState extends State<_VideoPickerField> {
  bool _uploading = false;
  String? _error;
  VideoPlayerController? _controller;
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.value);
    _loadPreview(widget.value);
  }

  @override
  void didUpdateWidget(covariant _VideoPickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        _urlController.text != widget.value) {
      _urlController.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
      _loadPreview(widget.value);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _urlController.dispose();
    super.dispose();
  }

  String _absolute(String path) => Uri.tryParse(path)?.hasScheme == true
      ? path
      : '${widget.api.baseUrl}${path.startsWith('/') ? '' : '/'}$path';

  Future<void> _loadPreview(String url) async {
    final previous = _controller;
    _controller = null;
    await previous?.dispose();
    if (url.trim().isEmpty || !mounted) {
      if (mounted) setState(() {});
      return;
    }
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(_absolute(url)),
    );
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() => _error = 'Video preview could not be loaded.');
      }
    }
  }

  Future<void> _pick() async {
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final url = await widget.api.uploadVideo(widget.parkSlug, file);
      if (mounted) {
        _urlController.value = TextEditingValue(
          text: url,
          selection: TextSelection.collapsed(offset: url.length),
        );
      }
      widget.onChanged(url);
      await widget.onUploaded?.call(url);
      await _loadPreview(url);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _clear() async {
    final previous = _controller;
    _controller = null;
    await previous?.dispose();
    if (mounted) {
      setState(() {
        _error = null;
        _urlController.clear();
      });
    }
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = widget.value.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: _ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (hasVideo)
              const _CmsPillBadge(
                label: 'Active',
                foreground: wonderlaSuccess,
                background: Color(0xFFECF9F2),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: wonderlaCream,
            border: Border.all(color: wonderlaBorder),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_controller?.value.isInitialized == true) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: wonderlaWhite,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: wonderlaBorder),
                    ),
                    child: const Icon(
                      Icons.videocam_outlined,
                      color: _brandNavy,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasVideo ? 'Banner video ready' : 'No video selected',
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasVideo
                              ? widget.value.trim()
                              : 'MP4, MOV or WebM · max 50 MB',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: wonderlaMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : _pick,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: wonderlaWhite,
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: _uploading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.video_library_outlined, size: 16),
                    label: Text(
                      _uploading
                          ? 'Uploading…'
                          : hasVideo
                          ? 'Replace video'
                          : 'Upload video',
                    ),
                  ),
                  if (hasVideo && !_uploading)
                    TextButton.icon(
                      onPressed: _clear,
                      style: TextButton.styleFrom(
                        foregroundColor: wonderlaFlagRed,
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 15),
                      label: const Text('Remove'),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          _CmsAlertBanner(
            message: _error!,
            tone: _CmsBannerTone.error,
            onDismiss: () => setState(() => _error = null),
          ),
        ],
        const SizedBox(height: 8),
        TextFormField(
          controller: _urlController,
          onChanged: widget.onChanged,
          onFieldSubmitted: _loadPreview,
          decoration: const InputDecoration(
            labelText: 'Or paste a video URL and press Enter',
            prefixIcon: Icon(Icons.link_rounded, size: 18),
            isDense: true,
          ),
        ),
      ],
    );
  }
}
