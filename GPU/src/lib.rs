use pyo3::prelude::*;
use ocl::{ProQue, Buffer};
use std::slice;

#[pyclass]
#[derive(Clone)]
struct DUCOHasher {
    base_data: Vec<u8>,
}

#[pymethods]
impl DUCOHasher {
    #[new]
    pub fn new(data: &[u8]) -> Self {
        Self {
            base_data: data.to_vec(),
        }
    }

    #[allow(non_snake_case)]
    pub fn DUCOS1(&self, expected_hash: &[u8], diff: u64, job_mul: u64) -> u64 {
        let max_nonce = diff * job_mul;
        if max_nonce == 0 {
            return 0;
        }

        let kernel_src = include_str!("kernel.cl");

        let pro_que = ProQue::builder()
            .src(kernel_src)
            .dims(1) // 占位，后面改
            .build()
            .ok();

        let mut pro_que = match pro_que {
            Some(pq) => pq,
            None => return 0,
        };

        let queue = pro_que.queue().clone();

        // 创建 buffers（复用）
        let base_data_buf = Buffer::builder()
            .queue(queue.clone())
            .len(self.base_data.len())
            .copy_host_slice(&self.base_data)
            .build()
            .unwrap();

        let expected_hash_buf = Buffer::builder()
            .queue(queue.clone())
            .len(expected_hash.len())
            .copy_host_slice(expected_hash)
            .build()
            .unwrap();

        let result_buf = Buffer::builder()
            .queue(queue.clone())
            .len(1)
            .build()
            .unwrap();

        // 分块大小（手机友好）
        let chunk_size = 131_072; // 128K，可调（Adreno 友好）
        let total = max_nonce;

        let mut start_nonce = 0u64;

        while start_nonce < total {
            let batch_size = ((start_nonce + chunk_size) as u64)
                .min(total)
                .saturating_sub(start_nonce) as usize;

            if batch_size == 0 {
                break;
            }

            // 更新 ProQue 维度
            pro_que.set_dims([batch_size]);

            // 重置 result
            let zero: u32 = 0;
            result_buf.write(slice::from_ref(&zero)).enq().unwrap();

            // 构建 kernel
            let kernel = pro_que.kernel_builder("duco_brute")
                .arg(&base_data_buf)
                .arg(self.base_data.len() as u32)
                .arg(&expected_hash_buf)
                .arg(start_nonce)          // 传起始 nonce
                .arg(batch_size as u64)    // 当前批次大小
                .arg(&result_buf)
                .build()
                .unwrap();

            // 执行这一批
            unsafe {
                if let Err(_) = kernel.enq() {
                    // 如果失败（如超时），跳过这一批
                    start_nonce += batch_size as u64;
                    continue;
                }
            }

            // 读结果
            let mut result: u32 = 0;
            if result_buf.read(slice::from_mut(&mut result)).enq().is_ok() && result != 0 {
                return u64::from(result);
            }

            start_nonce += batch_size as u64;

            // 可选：小休一下，防止过热
            // std::thread::sleep(std::time::Duration::from_micros(100));
        }

        0
    }
}

#[pymodule]
fn libducohasher(_py: Python, m: &Bound<PyModule>) -> PyResult<()> {
    m.add_class::<DUCOHasher>()?;
    Ok(())
}
