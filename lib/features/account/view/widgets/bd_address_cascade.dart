import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/features/account/repositories/geo_repository.dart';

/// Cascading Division → District → Post office + free-text city locality.
class BdAddressCascade extends ConsumerStatefulWidget {
  const BdAddressCascade({
    super.key,
    required this.division,
    required this.district,
    required this.postOffice,
    required this.postalCode,
    required this.city,
    required this.onChanged,
    this.fieldBuilder,
  });

  final String division;
  final String district;
  final String postOffice;
  final String postalCode;
  final String city;
  final void Function({
    String? division,
    String? district,
    String? postOffice,
    String? postalCode,
    String? city,
  }) onChanged;

  /// Optional custom field shell (label + child). Defaults to a simple column.
  final Widget Function(String label, Widget child)? fieldBuilder;

  @override
  ConsumerState<BdAddressCascade> createState() => _BdAddressCascadeState();
}

class _BdAddressCascadeState extends ConsumerState<BdAddressCascade> {
  late final TextEditingController _city;

  @override
  void initState() {
    super.initState();
    _city = TextEditingController(text: widget.city);
  }

  @override
  void didUpdateWidget(covariant BdAddressCascade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.city != widget.city && _city.text != widget.city) {
      _city.text = widget.city;
    }
  }

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  Widget _wrap(String label, Widget child) {
    final builder = widget.fieldBuilder;
    if (builder != null) return builder(label, child);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.label.copyWith(color: const Color(0xFF3C4660))),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF7F9FC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE3E8F1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE3E8F1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppPallete.primary),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final divisionsAsync = ref.watch(bdDivisionsProvider);
    final divisions = divisionsAsync.valueOrNull ?? const <BdDivision>[];
    BdDivision? selectedDivision;
    for (final item in divisions) {
      if (item.name == widget.division || item.slug == widget.division) {
        selectedDivision = item;
        break;
      }
    }
    final divisionKey = selectedDivision?.slug ?? '';
    final districtsAsync = ref.watch(bdDistrictsProvider(divisionKey));
    final districts = districtsAsync.valueOrNull ?? const <BdDistrict>[];
    BdDistrict? selectedDistrict;
    for (final item in districts) {
      if (item.name == widget.district || item.slug == widget.district) {
        selectedDistrict = item;
        break;
      }
    }
    final districtKey = selectedDistrict?.slug ?? '';
    final officesAsync = ref.watch(bdPostOfficesProvider(districtKey));
    final offices = officesAsync.valueOrNull ?? const <BdPostOffice>[];
    BdPostOffice? selectedOffice;
    for (final item in offices) {
      if (item.name == widget.postOffice &&
          (widget.postalCode.isEmpty || item.postalCode == widget.postalCode)) {
        selectedOffice = item;
        break;
      }
    }
    final officeValue =
        selectedOffice == null ? null : '${selectedOffice.name}|||${selectedOffice.postalCode}';

    final divisionHint = divisionsAsync.isLoading
        ? 'Loading…'
        : divisionsAsync.hasError
            ? 'Could not load divisions'
            : divisions.isEmpty
                ? 'No divisions available'
                : 'Select division';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (divisionsAsync.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              'Location list failed to load. Close and reopen this screen to retry.',
              style: AppTypography.label.copyWith(color: const Color(0xFFB42318)),
            ),
          ),
        _wrap(
          'Division',
          DropdownButtonFormField<String>(
            key: ValueKey('division-${selectedDivision?.slug ?? 'none'}'),
            initialValue: selectedDivision?.slug,
            isExpanded: true,
            decoration: _decoration(divisionHint),
            items: [
              for (final item in divisions)
                DropdownMenuItem(value: item.slug, child: Text(item.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: divisions.isEmpty
                ? null
                : (slug) {
                    BdDivision? next;
                    for (final item in divisions) {
                      if (item.slug == slug) {
                        next = item;
                        break;
                      }
                    }
                    widget.onChanged(
                      division: next?.name ?? '',
                      district: '',
                      postOffice: '',
                      postalCode: '',
                    );
                  },
          ),
        ),
        _wrap(
          'District',
          DropdownButtonFormField<String>(
            key: ValueKey('district-${selectedDistrict?.slug ?? 'none'}-${widget.division}'),
            initialValue: selectedDistrict?.slug,
            isExpanded: true,
            decoration: _decoration(
              widget.division.isEmpty
                  ? 'Select division first'
                  : districtsAsync.isLoading
                      ? 'Loading…'
                      : 'Select district',
            ),
            items: [
              for (final item in districts)
                DropdownMenuItem(value: item.slug, child: Text(item.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: widget.division.isEmpty
                ? null
                : (slug) {
                    BdDistrict? next;
                    for (final item in districts) {
                      if (item.slug == slug) {
                        next = item;
                        break;
                      }
                    }
                    widget.onChanged(
                      district: next?.name ?? '',
                      postOffice: '',
                      postalCode: '',
                    );
                  },
          ),
        ),
        _wrap(
          'Post office',
          DropdownButtonFormField<String>(
            key: ValueKey('office-${officeValue ?? 'none'}-${widget.district}'),
            initialValue: officeValue,
            isExpanded: true,
            decoration: _decoration(
              widget.district.isEmpty
                  ? 'Select district first'
                  : officesAsync.isLoading
                      ? 'Loading…'
                      : 'Select post office',
            ),
            items: [
              for (final item in offices)
                DropdownMenuItem(
                  value: '${item.name}|||${item.postalCode}',
                  child: Text('${item.name} (${item.postalCode})', overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: widget.district.isEmpty
                ? null
                : (raw) {
                    final parts = (raw ?? '').split('|||');
                    widget.onChanged(
                      postOffice: parts.isNotEmpty ? parts[0] : '',
                      postalCode: parts.length > 1 ? parts[1] : '',
                    );
                  },
          ),
        ),
        _wrap(
          'City / locality',
          TextField(
            controller: _city,
            textCapitalization: TextCapitalization.words,
            decoration: _decoration('Area, locality, or neighbourhood'),
            onChanged: (value) => widget.onChanged(city: value),
          ),
        ),
      ],
    );
  }
}
