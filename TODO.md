# Bakta Improvement TODO List

## Project Analysis Summary

**Bakta** is a sophisticated bacterial genome annotation tool designed for rapid, standardized annotation of bacterial genomes, MAGs (Metagenome-Assembled Genomes), and plasmids. This document outlines identified bottlenecks and improvement opportunities based on comprehensive codebase analysis.

## Architecture Overview

### Current Design Strengths
- ✅ **Modular Pipeline**: Clean separation between feature detection, database queries, and I/O operations
- ✅ **Hierarchical Annotation**: Progressive confidence levels from exact matches to homology-based annotations
- ✅ **Multi-threaded Processing**: Concurrent database lookups and sequence analysis
- ✅ **Configurable Workflow**: Extensible skip options for different feature types

### Key Components Analysis
- **Main Controller** (`main.py`): 627-line orchestrator managing the entire pipeline
- **Feature Modules** (`features/`): Specialized detection for tRNA, rRNA, CDS, sORF, etc.
- **Database Layer** (`ups.py`, `ips.py`, `psc.py`, `pscc.py`): Tiered search strategy
- **Expert Systems** (`expert/`): AMRFinder, custom proteins, HMMs
- **I/O Handlers** (`io/`): Multiple output format support

## Performance Bottlenecks Identified

### 1. Sequential Feature Processing ⚠️ **HIGH IMPACT**

**Current State**: Features processed sequentially despite independence

**Location**: Lines 157-444 in `main.py`
```python
# Sequential execution
predict_trnas()    # Could run in parallel
predict_tmrnas()   # with other RNA predictions
predict_rrnas()
predict_ncrnas()
```

**Impact**: 40-60% potential speedup for multi-core systems

### 2. Database Search Overhead ⚠️ **MEDIUM IMPACT**

**Current State**: Multiple DIAMOND searches with file I/O

**Location**: `psc.py:30-50`
```python
# Writes temp files for each search
diamond_output_path = cfg.tmp_path.joinpath('diamond.psc.tsv')
cds_aa_path = cfg.tmp_path.joinpath('cds.psc.faa')
```

**Impact**: Disk I/O latency, temporary file cleanup overhead

### 3. Thread Pool Inefficiency ⚠️ **MEDIUM IMPACT**

**Current State**: Multiple thread pools with inconsistent sizing
```python
# Different thread counts used across modules
ThreadPoolExecutor(max_workers=10)  # Database lookups
ThreadPoolExecutor(max_workers=cfg.threads)  # Gene prediction
```

**Impact**: Resource contention, suboptimal CPU utilization

### 4. Memory Accumulation ⚠️ **LOW IMPACT**

**Current State**: All features retained in memory throughout pipeline
```python
data['features'].extend(trnas)  # Growing feature list
data['features'].extend(rrnas)  # No intermediate cleanup
```

**Impact**: Memory pressure for large genomes (>50MB assemblies)

---

## Implementation Roadmap

### Phase 1: Core Performance Optimizations (2-3 weeks)

#### Priority 1: Parallel Feature Detection 🚀

**Status**: ⬜ TODO
**Assignee**: TBD
**Estimated Effort**: 5-8 days

**Implementation Plan**:
```python
def parallel_rna_prediction(data, sequences_path):
    """Run RNA predictions in parallel"""
    with ThreadPoolExecutor(max_workers=4) as executor:
        futures = {
            executor.submit(t_rna.predict_t_rnas, data, sequences_path): 'tRNA',
            executor.submit(tm_rna.predict_tm_rnas, data, sequences_path): 'tmRNA',
            executor.submit(r_rna.predict_r_rnas, data, sequences_path): 'rRNA',
            executor.submit(nc_rna.predict_nc_rnas, data, sequences_path): 'ncRNA'
        }

        results = {}
        for future in cf.as_completed(futures):
            feature_type = futures[future]
            results[feature_type] = future.result()
    return results
```

**Expected Benefit**: 3-4x speedup for RNA annotation phase
**Risk Level**: Medium (requires coordination testing)

**Tasks**:
- [ ] Refactor RNA prediction modules to support parallel execution
- [ ] Implement parallel coordination logic
- [ ] Add error handling for concurrent failures
- [ ] Test with various genome sizes
- [ ] Benchmark performance improvements

#### Priority 2: Database Connection Pool 🔄

**Status**: ⬜ TODO
**Assignee**: TBD
**Estimated Effort**: 3-5 days

**Implementation Plan**:
```python
class DatabaseManager:
    def __init__(self, db_path, pool_size=10):
        self.db_path = db_path
        self.connection_pool = queue.Queue(maxsize=pool_size)
        # Pre-populate pool with read-only connections

    @contextmanager
    def get_connection(self):
        """Get pooled database connection"""
        conn = self.connection_pool.get()
        try:
            yield conn
        finally:
            self.connection_pool.put(conn)
```

**Expected Benefit**: 20-30% reduction in database query overhead
**Risk Level**: Low (minimal API changes)

**Tasks**:
- [ ] Design database connection pool class
- [ ] Integrate with existing SQLite queries
- [ ] Add connection health monitoring
- [ ] Implement graceful pool shutdown
- [ ] Performance testing

#### Priority 3: Enhanced Threading Strategy ⚡

**Status**: ⬜ TODO
**Assignee**: TBD
**Estimated Effort**: 4-6 days

**Implementation Plan**:
```python
class BaktaThreadPool:
    def __init__(self):
        cpu_count = cfg.threads
        # I/O bound: 2-3x CPU count
        self.io_pool = ThreadPoolExecutor(max_workers=cpu_count * 3)
        # CPU bound: 1x CPU count
        self.cpu_pool = ThreadPoolExecutor(max_workers=cpu_count)

    def submit_io_task(self, func, *args, **kwargs):
        return self.io_pool.submit(func, *args, **kwargs)

    def submit_cpu_task(self, func, *args, **kwargs):
        return self.cpu_pool.submit(func, *args, **kwargs)
```

**Expected Benefit**: 15-25% overall performance improvement
**Risk Level**: Low (internal changes only)

**Tasks**:
- [ ] Create unified thread pool manager
- [ ] Categorize tasks by I/O vs CPU bound
- [ ] Replace existing ThreadPoolExecutor calls
- [ ] Add monitoring and metrics
- [ ] Tune pool sizes based on workload

### Phase 2: Memory & Scalability (3-4 weeks)

#### Priority 4: Streaming Architecture 📊

**Status**: ⬜ TODO
**Assignee**: TBD
**Estimated Effort**: 10-12 days

**Implementation Plan**:
```python
def process_sequences_streaming(sequences, chunk_size=1000000):
    """Process large genomes in chunks"""
    for chunk_start in range(0, total_length, chunk_size):
        chunk = extract_chunk(sequences, chunk_start, chunk_size)
        features = process_chunk(chunk)
        yield features  # Stream results
        gc.collect()  # Explicit memory management
```

**Expected Benefit**: Constant memory usage regardless of genome size
**Risk Level**: High (major architectural changes)

**Tasks**:
- [ ] Design chunking strategy for large genomes
- [ ] Implement feature streaming API
- [ ] Add overlap handling for chunk boundaries
- [ ] Update all feature detection modules
- [ ] Extensive testing with large assemblies

#### Priority 5: Memory Optimization 🗄️

**Status**: ⬜ TODO
**Assignee**: TBD
**Estimated Effort**: 5-7 days

**Implementation Plan**:
- Implement garbage collection at pipeline stages
- Add memory monitoring and profiling
- Optimize feature data structures

**Tasks**:
- [ ] Add memory usage profiling
- [ ] Implement feature cleanup at pipeline stages
- [ ] Optimize data structure memory footprint
- [ ] Add memory usage warnings
- [ ] Create memory benchmarking suite

### Phase 3: Advanced Optimizations (4-5 weeks)

#### Priority 6: Caching Layer 💾

**Status**: ⬜ TODO
**Assignee**: TBD
**Estimated Effort**: 8-10 days

**Implementation Plan**:
```python
from functools import lru_cache
from joblib import Memory

class AnnotationCache:
    def __init__(self, cache_dir):
        self.memory = Memory(cache_dir, verbose=0)

    @lru_cache(maxsize=10000)
    def lookup_ups(self, md5_hash):
        """Cache UPS lookups"""
        return self._fetch_ups(md5_hash)

    def cache_diamond_results(self, query_hash, results):
        """Cache expensive DIAMOND searches"""
        return self.memory.cache(self._diamond_search)
```

**Expected Benefit**: 50-80% speedup for repeated annotations
**Risk Level**: Medium (cache invalidation complexity)

**Tasks**:
- [ ] Design caching architecture
- [ ] Implement cache invalidation strategies
- [ ] Add cache size management
- [ ] Integrate with database lookups
- [ ] Performance benchmarking

#### Priority 7: Database Schema Optimization 🗃️

**Status**: ⬜ TODO
**Assignee**: TBD
**Estimated Effort**: 6-8 days

**Tasks**:
- [ ] Analyze current database query patterns
- [ ] Add missing indexes for common queries
- [ ] Optimize SQLite pragma settings
- [ ] Implement query result caching
- [ ] Benchmark database performance improvements

### Phase 4: Code Quality & Testing (2-3 weeks)

#### Priority 8: Type Hinting Enhancement 📝

**Status**: ⬜ TODO
**Assignee**: TBD
**Estimated Effort**: 4-6 days

**Implementation Plan**:
```python
from typing import Dict, List, Optional, Union, Protocol

class FeatureDetector(Protocol):
    def predict(self, data: GenomeData, sequences_path: Path) -> List[Feature]:
        ...
```

**Tasks**:
- [ ] Add comprehensive type hints to all modules
- [ ] Create type definitions for data structures
- [ ] Set up mypy for type checking
- [ ] Add type validation in critical paths

#### Priority 9: Error Handling Standardization 🛡️

**Status**: ⬜ TODO
**Assignee**: TBD
**Estimated Effort**: 3-4 days

**Implementation Plan**:
```python
class BaktaError(Exception):
    """Base exception for Bakta-specific errors"""
    pass

class DatabaseError(BaktaError):
    """Database connection/query errors"""
    pass
```

**Tasks**:
- [ ] Create exception hierarchy
- [ ] Standardize error handling patterns
- [ ] Add proper error logging
- [ ] Implement graceful degradation

#### Priority 10: Configuration Validation 📋

**Status**: ⬜ TODO
**Assignee**: TBD
**Estimated Effort**: 2-3 days

**Implementation Plan**:
```python
from pydantic import BaseModel, validator

class BaktaConfig(BaseModel):
    threads: int
    db_path: Path

    @validator('threads')
    def validate_threads(cls, v):
        return max(1, min(v, mp.cpu_count() * 2))
```

**Tasks**:
- [ ] Implement configuration validation
- [ ] Add runtime parameter checking
- [ ] Create configuration schema
- [ ] Add validation error messages

#### Priority 11: Performance Testing Suite 📊

**Status**: ⬜ TODO
**Assignee**: TBD
**Estimated Effort**: 5-7 days

**Implementation Plan**:
```python
@pytest.mark.benchmark
def test_annotation_performance(benchmark, sample_genome):
    result = benchmark(annotate_genome, sample_genome)
    assert len(result['features']) > 0
    assert benchmark.stats['mean'] < 300  # seconds
```

**Tasks**:
- [ ] Create performance benchmark suite
- [ ] Add memory profiling tests
- [ ] Implement regression testing
- [ ] Set up CI performance monitoring

---

## Expected Performance Improvements

| Optimization | Current Time | Optimized Time | Speedup | Memory Reduction |
|--------------|--------------|----------------|---------|------------------|
| RNA Prediction | 120s | 30s | 4x | - |
| Database Queries | 180s | 130s | 1.4x | - |
| Overall Pipeline | 600s | 300s | 2x | - |
| Memory Usage | 4GB | 1.5GB | - | 2.7x |

## Risk Assessment & Mitigation

### Low Risk ✅
- Database connection pooling (minimal API changes)
- Thread pool optimization (internal changes only)
- Type hinting (non-functional improvement)

**Mitigation**: Comprehensive unit tests, gradual rollout

### Medium Risk ⚠️
- Parallel RNA prediction (requires coordination testing)
- Caching implementation (cache invalidation complexity)
- Configuration validation (potential breaking changes)

**Mitigation**: Feature flags, extensive integration testing, backward compatibility

### High Risk ❌
- Streaming architecture (major architectural changes)
- Feature processing pipeline refactor

**Mitigation**: Phased implementation, prototype validation, extensive testing

---

## Testing Strategy

### Unit Tests
- [ ] Maintain >90% code coverage
- [ ] Test all new threading logic
- [ ] Validate caching mechanisms
- [ ] Test error handling paths

### Integration Tests
- [ ] End-to-end pipeline tests
- [ ] Database connection pool stress tests
- [ ] Large genome memory usage tests
- [ ] Multi-threading coordination tests

### Performance Tests
- [ ] Benchmark each optimization
- [ ] Memory usage profiling
- [ ] Stress testing with large datasets
- [ ] Regression testing suite

### Compatibility Tests
- [ ] Backward compatibility validation
- [ ] Output format consistency
- [ ] Cross-platform testing
- [ ] Database version compatibility

---

## Monitoring & Metrics

### Performance Metrics
- [ ] Annotation time per genome size
- [ ] Database query response times
- [ ] Memory usage patterns
- [ ] Thread pool utilization

### Quality Metrics
- [ ] Annotation accuracy comparison
- [ ] Output format validation
- [ ] Error rates and handling
- [ ] Feature detection coverage

---

## Documentation Updates Required

### Developer Documentation
- [ ] Architecture overview updates
- [ ] API documentation for new classes
- [ ] Performance tuning guidelines
- [ ] Troubleshooting guides

### User Documentation
- [ ] Performance optimization recommendations
- [ ] Memory usage guidelines
- [ ] Configuration best practices
- [ ] Migration guides

---

## Success Criteria

### Performance Goals
- **2x overall speedup** for typical bacterial genomes
- **4x speedup** for RNA annotation phase
- **60% memory usage reduction** for large genomes
- **30% reduction** in database query overhead

### Quality Goals
- Maintain **100% backward compatibility**
- **Zero regression** in annotation accuracy
- **<5% increase** in complexity metrics
- **>95% test coverage** for new code

### Timeline Goals
- **Phase 1**: 3 weeks (core performance)
- **Phase 2**: 4 weeks (memory & scalability)
- **Phase 3**: 5 weeks (advanced optimizations)
- **Phase 4**: 3 weeks (quality & testing)
- **Total**: ~15 weeks

---

## Dependencies & Prerequisites

### Technical Dependencies
- Python 3.9+ (current requirement)
- Updated testing frameworks (pytest-benchmark)
- Memory profiling tools (tracemalloc, psutil)
- Performance monitoring (cProfile, py-spy)

### Resource Requirements
- Development environment with >16GB RAM
- Access to large test genomes (>100MB)
- Performance testing hardware
- CI/CD pipeline updates

### External Dependencies
- DIAMOND (current version compatibility)
- PyHMMER (threading compatibility)
- SQLite optimization features
- Container environment for testing

---

## Notes & Considerations

### Backward Compatibility
- All optimizations must maintain existing API
- Output formats must remain consistent
- Configuration options preserved
- Database format compatibility required

### Platform Support
- Linux (primary target)
- macOS (developer environment)
- Windows (via Docker)
- Container environments

### Maintenance
- Regular performance regression testing
- Database optimization monitoring
- Memory leak detection
- Thread safety validation

---

*Last Updated*: 2025-11-21
*Next Review*: TBD
*Owner*: TBD

## Quick Start Checklist for Implementation

### Immediate Actions (Week 1)
- [ ] Set up development environment
- [ ] Create feature branch for Phase 1
- [ ] Implement basic performance benchmarking
- [ ] Begin parallel RNA prediction refactor

### Short-term Actions (Weeks 2-4)
- [ ] Complete Priority 1-3 implementations
- [ ] Add comprehensive testing
- [ ] Begin database connection pooling
- [ ] Performance validation and tuning

### Long-term Actions (Weeks 5-15)
- [ ] Implement streaming architecture
- [ ] Add caching layer
- [ ] Complete code quality improvements
- [ ] Final performance validation and documentation